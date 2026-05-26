--Query for order activity across the order, item and address tables
SELECT
	o.order_id,
	i.item_price,
	o.quantity,
	i.item_category,
	i.item_name,
	o.created_at,
	a.delivery_address1,
	a.delivery_address2,
	a.delivery_city,
	a.delivery_zipcode,
	o.delivery
FROM orders o
LEFT JOIN items i
	ON o.item_id = i.item_id
LEFT JOIN address a
	ON o.add_id = a.add_id;

--query for the quantity of order per available item on menu
SELECT 
	o.item_id,
	i.sku,
	i.item_name,
	sum(o.quantity) AS order_quantity
FROM orders o
LEFT JOIN items i
	ON o.item_id = i.item_id
GROUP BY (o.item_id,i.sku,i.item_name);

-- Breaking down each item by ingredient
SELECT
	o.item_id,
	i.sku,
	i.item_name,
	ing.ing_name,
	r.ing_id,
	ing.ing_weight,
	ing.ing_price,
	r.quantity AS recipe_quantity,
	sum(o.quantity) AS order_quantity
FROM orders o
LEFT JOIN items i
	ON o.item_id = i.item_id
LEFT JOIN recipes r
	ON i.sku = r.recipe_id
LEFT JOIN ingredients ing
	ON r.ing_id = ing.ing_id
GROUP BY (
	o.item_id,
	i.sku,
	i.item_name,
	ing.ing_name,
	r.ing_id,
	ing.ing_weight,
	ing.ing_price,
	r.quantity
	);

--From the subquery, extracting inventory mgt. metrics (cost of ingredient, total qty by ingredient etc.)
SELECT 
	s1.item_name,
	s1.ing_id,
	s1.ing_name,
	s1.ing_price,
	s1.ing_weight,
	s1.order_quantity,
	s1.recipe_quantity,
	(s1.recipe_quantity * s1.order_quantity) AS ordered_weight,
	ROUND((s1.ing_price/s1.ing_weight),6) AS unit_cost,
	ROUND((s1.recipe_quantity * s1.order_quantity)*(s1.ing_price/s1.ing_weight),2) AS total_ingredient_cost
FROM (
	SELECT
		o.item_id,
		i.sku,
		i.item_name,
		ing.ing_name,
		r.ing_id,
		ing.ing_weight,
		ing.ing_price,
		r.quantity AS recipe_quantity,
		sum(o.quantity) AS order_quantity
	FROM orders o
	LEFT JOIN items i
		ON o.item_id = i.item_id
	LEFT JOIN recipes r
		ON i.sku = r.recipe_id
	LEFT JOIN ingredients ing
		ON r.ing_id = ing.ing_id
	GROUP BY (
		o.item_id,
		i.sku,
		i.item_name,
		ing.ing_name,
		r.ing_id,
		ing.ing_weight,
		ing.ing_price,
		r.quantity
		)
	) AS s1;

--- Saving the generated table as a view
CREATE VIEW inv_mgt
AS SELECT 
	s1.item_name,
	s1.ing_id,
	s1.ing_name,
	s1.ing_price,
	s1.ing_weight,
	s1.order_quantity,
	s1.recipe_quantity,
	(s1.recipe_quantity * s1.order_quantity) AS ordered_weight,
	ROUND((s1.ing_price/s1.ing_weight),6) AS unit_cost,
	ROUND((s1.recipe_quantity * s1.order_quantity)*(s1.ing_price/s1.ing_weight),2) AS total_ingredient_cost
FROM (
	SELECT
		o.item_id,
		i.sku,
		i.item_name,
		ing.ing_name,
		r.ing_id,
		ing.ing_weight,
		ing.ing_price,
		r.quantity AS recipe_quantity,
		sum(o.quantity) AS order_quantity
	FROM orders o
	LEFT JOIN items i
		ON o.item_id = i.item_id
	LEFT JOIN recipes r
		ON i.sku = r.recipe_id
	LEFT JOIN ingredients ing
		ON r.ing_id = ing.ing_id
	GROUP BY (
		o.item_id,
		i.sku,
		i.item_name,
		ing.ing_name,
		r.ing_id,
		ing.ing_weight,
		ing.ing_price,
		r.quantity
		)
	) AS s1;
;

--- Querying for total weight ordered
SELECT 
	ing_name,
	sum(ordered_weight) AS ordered_weight
FROM inv_mgt
GROUP BY ing_name;

-- Joining the inventory table to get the quantity for each ingredient in stock
SELECT *
FROM(
	SELECT
		ing_id,
		ing_name,
		sum(ordered_weight) AS ordered_weight
	FROM inv_mgt
	GROUP BY ing_name,ing_id
	) s2
LEFT JOIN inventory inv
	ON s2.ing_id = inv.item_id;

-- Querying for the total inventory weight
SELECT 
	s2.ing_name,
	s2.weight_ordered,
	(ing.ing_weight*inv.quantity) AS total_inv_weight,
	(ing.ing_weight*inv.quantity) - s2.weight_ordered AS weight_left_in_stock
FROM(
	SELECT
		ing_id,
		ing_name,
		sum(ordered_weight) AS weight_ordered
	FROM inv_mgt
	GROUP BY ing_name,ing_id
	) s2
LEFT JOIN inventory inv
	ON s2.ing_id = inv.item_id
LEFT JOIN ingredients ing
	ON s2.ing_id = ing.ing_id;


-- Querying for the staff hourly rate, and shift times
SELECT
	st.staff_firstname,
	st.staff_lastname,
	ro.date,
	st.hourly_rate,
	sh.start_time,
	sh.end_time
FROM staff st
LEFT JOIN rotations ro
	ON st.staff_id = ro.staff_id
LEFT JOIN shifts sh
	ON ro.shift_id = sh.shift_id;

-- Calculating the staff cost per row
SELECT
	ro.shift_id,
	ro.staff_id,
	sh.shift_id,
	st.staff_firstname,
	st.staff_lastname,
	ro.date,
	st.hourly_rate,
	sh.start_time,
	sh.end_time,
	ROUND((EXTRACT (EPOCH FROM(sh.end_time - sh.start_time)))/3600,2) AS hours_in_shift,
	ROUND((EXTRACT (EPOCH FROM(sh.end_time - sh.start_time)))/3600,2) * st.hourly_rate AS staff_cost
FROM staff st
LEFT JOIN rotations ro
	ON st.staff_id = ro.staff_id
LEFT JOIN shifts sh
	ON ro.shift_id = sh.shift_id;



