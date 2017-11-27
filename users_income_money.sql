-- Procedure to calculate earning of partners per day and per week. Run by cron every 5 minutes.
-- From table "users_balance" retrieve earnings of every user per day and per week. Retrieving is for
-- users, whose roleId in "user" table is 7, and operation type in "balance" table is 4 (earning for placing building)

DELIMITER $$
CREATE PROCEDURE users_income_money(IN user_role INT,
                                    IN type_operation INT,
                                    IN status_enabled INT)
    BEGIN
        DECLARE user_id INT(11);    -- ID of user, with whome we will work. Retrieve one by one from cursor
        DECLARE amount FLOAT(12,2); -- amount (per day and week) for user. Retrieve one by one from cursor with user
        
        DECLARE done INT DEFAULT 0;
        
        -- Cursor, where will be earnings for all users(partners, roleId = 7) for today
        DECLARE daylyMoneyCursor CURSOR FOR
                SELECT userId, SUM(sum) as sum
                FROM users_balance
                WHERE type = type_operation
                AND DATE(date_add) = DATE(NOW())
                AND userId IN(
                        SELECT userId
                        FROM users_roles
                        WHERE roleId = user_role
                        AND status = status_enabled
                    )
                GROUP BY userId;
        
        -- Cursor, where will be earnings for all users(partners, roleId = 7) for week
        DECLARE weeklyMoneyCursor CURSOR FOR
                SELECT userId, SUM(sum) as sum
                FROM users_balance
                WHERE type = type_operation
                AND DATE(date_add) >= DATE(DATE_SUB(NOW(), INTERVAL WEEKDAY(NOW()) DAY))
                AND DATE(date_add) <= DATE(NOW())
                AND userId IN(
                        SELECT userId
                        FROM users_roles
                        WHERE roleId = user_role
                        AND status = status_enabled
                    )
                GROUP BY userId;
        
        DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

        -- Открытие курсора и считывание из него первой пары значений(userId, sum) - заработок партнера за сегодня
        -- в переменные user_id и amount
        
        -- Open cursor and fetch first pair userId=>sum - earnings of partner for today, into variables user_id and amount
        OPEN daylyMoneyCursor;
        FETCH daylyMoneyCursor INTO user_id, amount;

        WHILE done = 0 DO                        
            -- For user with ID like user_id (get from cursor) update earning for today.
            -- Earning is "amount", which also get from cursor
            UPDATE users
            SET incomeToday = amount
            WHERE userId = user_id;

            -- Get next pair of values from cursor
            FETCH daylyMoneyCursor INTO user_id, amount;
        END WHILE;
        
        -- Don't forget close cursor and reset flag for next cursor
        CLOSE daylyMoneyCursor;
        SET done = 0;

        -- Open cursor and fetch first pair of values
        OPEN weeklyMoneyCursor;
        FETCH weeklyMoneyCursor INTO user_id, amount;
        
        -- Update users earnings for week
        WHILE done = 0 DO
            UPDATE users
            SET incomeWeek = amount
            WHERE userId = user_id;

            FETCH weeklyMoneyCursor INTO user_id, amount;
        END WHILE;

        CLOSE weeklyMoneyCursor;

    END$$
DELIMITER ;
