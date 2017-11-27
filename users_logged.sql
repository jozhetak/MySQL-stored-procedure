DELIMITER $$
CREATE PROCEDURE users_logged(IN session_duration INT(2))
    BEGIN
    
        -- Variable-flag for breaking loop and cursor, where users ID will be write in which date_logout = '0000-00-00 00:00:00'.        
        DECLARE done INT DEFAULT 0;
        DECLARE user_id INT;
        DECLARE userSetCursor CURSOR FOR
                SELECT userId FROM users_logged WHERE (date_logout = '0000-00-00 00:00:00');
        
        -- Exception what to do, when all data will retrieve from cursor. Set "done" variable value 1 to exit from loop
        DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;        
        
        -- Update date_logout in users, who "forgot" exit (during some interfal they do nothing)
        -- Open cursor and retrieve first value (ID of user, who "forgot" to exit)
        OPEN userSetCursor;
        FETCH userSetCursor INTO user_id;

        WHILE done = 0 DO
            SET @user_last_activity = NULL;
            
            -- Get date and time of last activity of current user
            SELECT @user_last_activity := max(date_add)
            FROM users_history_visit
            WHERE userId = user_id
            ORDER BY date_add DESC
            LIMIT 0,1;            
            
            -- If last user activity (last record in "user_history_visit") was earlier then 30 minutes ago (35min, 40min ... ago)
            -- set date and time of last activity in "users_logged" as exit date

            UPDATE users_logged
            SET date_logout =
                CASE
                    WHEN @user_last_activity < DATE_SUB(NOW(), INTERVAL session_duration MINUTE)
                        THEN @user_last_activity
                    ELSE
                        '0000-00-00 00:00:00'
                END
            WHERE date_logout = '0000-00-00 00:00:00'
            AND userId = user_id;
            
            -- set date of last activity in table "user" for users, who are still "online"
            UPDATE users
            SET last_access = @user_last_activity
            WHERE userId = user_id;
            
            -- Read next record (ID of user) from cursor. 
            FETCH userSetCursor INTO user_id;
        END WHILE;

        -- Close cursor
        CLOSE userSetCursor;        
        
        -- Update count minutes of using site to those users, who currently online, or whose session expired (time inactivity)
        -- and above query kicked them
        UPDATE users_logged
        SET minutes =
            CASE
                WHEN date_logout = '0000-00-00 00:00:00'
                    THEN (UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(date_login)) / 60
                WHEN date_logout <> '0000-00-00 00:00:00'
                    THEN (UNIX_TIMESTAMP(date_logout) - UNIX_TIMESTAMP(date_login)) / 60
            END        
        -- users, who in the site now and their session not expired. It's temporaty time of staing
        WHERE date_logout = '0000-00-00 00:00:00'                
        -- or that, whose session already expired ("forgot" to exit) and "date_logout" was set to them.
        -- User logged out from site (previous query kicked them), and it's total time of staing in the site
        OR minutes = 0;        
        
        -- Update minutes in "users" table to users, which after checking session still online. Also update session time "last_session_time".
        -- To users, who online, fields "minutes" and "last_session_time" has same value in table "user"
        UPDATE users, users_logged
        SET users.minutes = users_logged.minutes, users.last_session_time = users_logged.minutes
        WHERE users_logged.date_logout = '0000-00-00 00:00:00'
        AND users.userId = users_logged.userId;        
        
        -- Update minutes in table "user" to users, who were kicked from account after checking session.
        UPDATE users, users_logged
        SET users.minutes = 0, users.last_session_time = users_logged.minutes
        WHERE users_logged.date_logout <> '0000-00-00 00:00:00'
        AND users.userId = users_logged.userId
        AND users.last_access = users_logged.date_logout;
    
    END$$
DELIMITER ;
