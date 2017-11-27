DROP PROCEDURE IF EXISTS searchItemsByCharactericValues;

DELIMITER $$
CREATE PROCEDURE searchItemsByCharactericValues(IN characteristicValue VARCHAR(10000),
                                                OUT totalItemIds VARCHAR(10000))
BEGIN

    SET @done         = 0;
    SET @totalItemIds = NULL;
    SET @characteristicValue    = characteristicValue;
    SET @characteristicValueIds = NULL;

    -- set GROUP_CONCAT limit more, because by default string length is 1024 character
    SET SESSION group_concat_max_len = 1000000;

    IF LOCATE('-', @characteristicValue) > 0 THEN
        myloop: WHILE @done = 0 DO

            -- items ID in current iteration
            SET @itemIds = NULL;
            
            -- retrieve group of characteristic value and split it by comma
            SET @characteristicValueIds = SUBSTRING(@characteristicValue, 1, LOCATE('-', @characteristicValue) - 1);
            SET @characteristicValueIds = REPLACE(@characteristicValueIds, '_', ',');
            
            -- get items ID by characteristic value ID
            IF @totalItemIds IS NULL THEN
                SELECT GROUP_CONCAT(item_id) INTO @itemIds
                FROM item_2_characteristic_value
                WHERE FIND_IN_SET(characteristic_value_id, @characteristicValueIds);
            ELSE
                SELECT GROUP_CONCAT(item_id) INTO @itemIds
                FROM item_2_characteristic_value
                WHERE FIND_IN_SET(characteristic_value_id, @characteristicValueIds)
                AND FIND_IN_SET(item_id, @totalItemIds);
            END IF;
            
            -- current items set add to common set
            SET @totalItemIds = @itemIds;
            IF @itemIds IS NULL THEN
                LEAVE myloop;
            END IF;
            
            -- move to next group of characteristic values, we will work with it in next iteration
            SET @characteristicValue = SUBSTRING(@characteristicValue, LOCATE('-', @characteristicValue) + 1);
            
            -- if it is last group, get items ID by it
            IF LOCATE('-', @characteristicValue) = 0 THEN

                SET @done    = 1;
                SET @itemIds = NULL;

                SET @characteristicValueIds = REPLACE(@characteristicValue, '_', ',');

                SELECT GROUP_CONCAT(item_id) INTO @itemIds
                FROM item_2_characteristic_value
                WHERE FIND_IN_SET(characteristic_value_id, @characteristicValueIds)
                AND FIND_IN_SET(item_id, @totalItemIds);

                SET @totalItemIds = @itemIds;
            END IF;
        END WHILE;
    ELSE

        SET @itemIds = NULL;
        
        -- split characteristic values by comma
        SET @characteristicValueIds = REPLACE(@characteristicValue, '_', ',');

        -- get items ID by characteristic value ID
        SELECT GROUP_CONCAT(item_id) INTO @itemIds
        FROM item_2_characteristic_value
        WHERE FIND_IN_SET(characteristic_value_id, @characteristicValueIds);

        -- current items set add to common set
        SET @totalItemIds = @itemIds;
    END IF;

    -- setting OUT variable, then we will get it via SELECT @totalItemIds
    SET totalItemIds = @totalItemIds;

END$$
DELIMITER ;
