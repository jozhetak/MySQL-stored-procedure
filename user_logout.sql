-- Procedure update users date last activity, which logout.
-- We need take actual and right date of last activity. For this we select from tables "users_history_visit" and "users_visit"
-- and compare it. More actual date write in table "user" in field "last_access".
-- Necessary of comparing is need, because cron, whick update "users_history_visit" run every 5 minutes and
-- during 5 minutes after running user can stay on site. Finally date of last activity will be in table "users_visit",
-- because there writing date and time of visiting pages.
-- Also reseting field "minutes" = 0. That mean, that user "offline"

DELIMITER $$
CREATE PROCEDURE user_logout(IN user_id INT(11))
    BEGIN        
        -- date of last activity from history table "users_history_visit"
        SET @last_history_access = NULL;        
        -- date of last activity from table "users_visit". It wasn't move to history table by cron
        SET @last_visit_access = NULL;        
        -- time of login. Need for calculate time of staying during last session
        SET @login_date = NULL;        
        -- last session time. For writing in table "user" in field "last_session_time"
        SET @session_time = NULL;
        
        -- get login date and time of last session (from which user logging out)
        SELECT @login_date := date_login
        FROM users_logged
        WHERE userId = user_id
        AND date_logout = '0000-00-00 00:00:00';
        
        -- calculate time of last session
        SET @session_time = (UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(@login_date)) / 60;
        
        -- get date and time of last activity from history table "users_history_visit"
        SELECT @last_history_access := max(date_add)
        FROM users_history_visit
        WHERE userId = user_id
        ORDER BY date_add DESC
        LIMIT 0,1;
        
        -- get date and time of last activity from visits table "users_visit"
        SELECT @last_visit_access := max(date_add)
        FROM users_visit
        WHERE userId = user_id
        ORDER BY date_add DESC
        LIMIT 0,1;        
        
        -- if in table "users_visit" exists data for current user, so this date of last activity always bigger,
        -- then date of last activity from history, because date writes in this table earlier
        -- and then move to history by cron
        IF @last_visit_access IS NOT NULL THEN
            UPDATE users
            SET last_access = @last_visit_access, minutes = 0, last_session_time = @session_time
            WHERE userId = user_id;                
        -- if in table "users_visit" there are no data for current user, just take last date activity @last_history_access
        -- from history visits "users_history_visit" and update "last_access" in table "user"
        ELSEIF @last_visit_access IS NULL THEN
            IF @last_history_access IS NOT NULL THEN
                UPDATE users
                SET last_access = @last_history_access, minutes = 0, last_session_time = @session_time
                WHERE userId = user_id;
            END IF;
        END IF;
    END$$
DELIMITER ;
