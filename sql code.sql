------------------------------------------ TABLES ------------------------------------------
CREATE TABLE seller (
  Seller_id DECIMAL(8) NOT NULL,
  SellerName VARCHAR(64),
  SellerEmail VARCHAR(64),
  SellerPhone VARCHAR(12),
  PRIMARY KEY (Seller_id)
);

CREATE TABLE Category (
  Category_id DECIMAL(8) NOT NULL,
  CategoryName VARCHAR(64) NOT NULL,
  PRIMARY KEY (Category_id)
);

CREATE TABLE Warehouse (
  Warehouse_id DECIMAL(8) NOT NULL,
  WarehouseName VARCHAR(64) NOT NULL,
  WarehouseAddress VARCHAR(64) NOT NULL,
  Manager VARCHAR(128),
  PRIMARY KEY (Warehouse_id)
);

CREATE TABLE Customer (
  User_id DECIMAL(8) NOT NULL,
  Username VARCHAR(64) NOT NULL,
  Address VARCHAR(64) NOT NULL,
  Phone VARCHAR(12) NOT NULL,
  Email VARCHAR(32) NOT NULL,
  FirstName VARCHAR(32) NOT NULL,
  LastName VARCHAR(32) NOT NULL,
  PRIMARY KEY (User_id)
);

CREATE TABLE Product (
  Product_id DECIMAL(8) NOT NULL,
  ProductName VARCHAR(64) NOT NULL,
  ProductPrice DECIMAL(8,2) NOT NULL,
  ProductDescription VARCHAR(255),
  Category_id DECIMAL(8) NOT NULL,
  PRIMARY KEY (Product_id),
  FOREIGN KEY (Category_id) REFERENCES Category(Category_id)
);


CREATE TABLE Product_Seller (
  Seller_id DECIMAL(8) NOT NULL,
  Product_id DECIMAL(8) NOT NULL,
  PRIMARY KEY (Seller_id, Product_id),
  FOREIGN KEY (Seller_id) REFERENCES Seller(Seller_id),
  FOREIGN KEY (Product_id) REFERENCES Product(Product_id)
);

CREATE TABLE PurchaseOrder (
  Order_id DECIMAL(8) NOT NULL,
  User_id DECIMAL(8) NOT NULL,
  Product_id DECIMAL(8) NOT NULL,
  Seller_id DECIMAL(8) NOT NULL,
  Quantity DECIMAL(8) NOT NULL,
  SubTotal DECIMAL(12,2) NOT NULL,
  ShippingSpeed VARCHAR(32) NOT NULL,
  TrackingNumber VARCHAR(64),
  PRIMARY KEY (Order_id),
  FOREIGN KEY (user_id) REFERENCES Customer(user_id),
  FOREIGN KEY (Product_id) REFERENCES Product(Product_id),
  FOREIGN KEY (Seller_id) REFERENCES Seller(Seller_id)
);

CREATE TABLE Product_Delivery (
  Delivery_id DECIMAL(8) NOT NULL,
  Seller_id DECIMAL(8) NOT NULL,
  Product_id DECIMAL(8) NOT NULL,
  Warehouse_id DECIMAL(8) NOT NULL,
  DeliveryQuantity DECIMAL(12) NOT NULL,
  Condition VARCHAR(32),
  PRIMARY KEY (Delivery_id),
  FOREIGN KEY (Seller_id) REFERENCES Seller(Seller_id),
  FOREIGN KEY (Product_id) REFERENCES Product(Product_id),
  FOREIGN KEY (Warehouse_id) REFERENCES Warehouse(Warehouse_id)
);

CREATE TABLE inventory (
  Product_id DECIMAL(8) NOT NULL,
  Warehouse_id DECIMAL(8) NOT NULL,
  Seller_id DECIMAL(8) NOT NULL,
  Quantity DECIMAL(12) NOT NULL,
  Condition VARCHAR(32),
  PRIMARY KEY (Product_id, Warehouse_id),
  FOREIGN KEY (Product_id) REFERENCES Product(Product_id),
  FOREIGN KEY (Warehouse_id) REFERENCES Warehouse(Warehouse_id),
  FOREIGN KEY (Seller_id) REFERENCES Seller(Seller_id)
);

------------------------------------------ SEQUENCES ------------------------------------------
CREATE SEQUENCE Seller_seq START WITH 1;
CREATE SEQUENCE Category_seq START WITH 1;
CREATE SEQUENCE Warehouse_seq START WITH 1;
CREATE SEQUENCE Customer_seq START WITH 1;
CREATE SEQUENCE Product_seq START WITH 1;
CREATE SEQUENCE Product_Seller_seq START WITH 1;
CREATE SEQUENCE PurchaseOrder_seq START WITH 1;
CREATE SEQUENCE Product_Delivery_seq START WITH 1;
CREATE SEQUENCE inventory_seq START WITH 1;

------------------------------------------ INDEXES -----------------------------------------------
--Replace this with your index creations.
CREATE INDEX product_name_idx ON Product(productName);
CREATE INDEX customer_first_last_name_idx ON customer(firstName, lastName);
CREATE INDEX username_idx ON customer(username);
CREATE INDEX seller_name_idx ON seller(sellerName);
--------------------------------------- STORED PROCEDURES ------------------------------------------
-- New Product Use Case --
CREATE OR REPLACE PROCEDURE ADD_NEW_PRODUCT( 
 p_product_name IN VARCHAR, -- The name of the product. 
 p_product_price IN DECIMAL, -- The price of the product. 
 p_product_description IN VARCHAR, -- The description of the product. 
 p_product_category IN VARCHAR) -- The category of the product. 
 LANGUAGE plpgsql 
AS $$ 
DECLARE 
 v_category_id DECIMAL(8); --Declare a variable to hold the ID of the item code. 
BEGIN 
 -- first check if this product already exists. 
 IF p_product_name IN (select productname from product) THEN 
 RAISE EXCEPTION USING MESSAGE = 'This product already exist, new listing is not required', 
 ERRCODE = 22000; 
 -- then check if the product category is correct
 ELSEIF p_product_category NOT IN (select categoryName from Category) THEN
 RAISE EXCEPTION USING MESSAGE = 'Product category does not exist', 
 ERRCODE = 22000; 
 END IF; 
 --Get the category_id.
 SELECT category_id
 INTO v_category_id
 FROM Category 
 WHERE CategoryName = p_product_category; 
 --Insert the new product. 
 INSERT INTO Product(product_id, productName, productPrice, productDescription, category_id) 
 VALUES(nextval('product_seq'), p_product_name, p_product_price, p_product_description, v_category_id); 
END; 
$$; 


-- Product Delivery Use Case -- 
CREATE OR REPLACE PROCEDURE PRODUCT_DELIVERY( 
 p_seller_id IN DECIMAL,  -- seller id
 p_product_name IN VARCHAR, -- The name of the product. 
 p_quantity IN DECIMAL, -- Quantity of the product to deliver 
 p_condition IN VARCHAR, -- The condition of the product. 
 p_warehouse_name IN VARCHAR) -- Destination Warehouse. 
 LANGUAGE plpgsql 
AS $$ 
DECLARE 
 v_product_id DECIMAL(8); --Declare a variable to hold the ID of product 
 v_warehouse_id DECIMAL(8); --Declare a variable to hold the ID of warehouse
 v_quantity DECIMAL(12); --Declare a variable to hold the new quantity
BEGIN 
 --Get the product_id.
 SELECT product_id INTO v_product_id FROM Product
 WHERE productName = p_product_name; 
 --Get the warehouse_id.
 SELECT warehouse_id INTO v_warehouse_id FROM Warehouse
 WHERE warehouseName = p_warehouse_name; 
 --Get the new quantity after develivery
 IF -- if there are already some product in the inventory
    v_product_id IN (select product_id from inventory) and
    v_warehouse_id IN (select warehouse_id from inventory) and
	p_seller_id IN (select seller_id from inventory) THEN
 SELECT p_quantity + (SELECT quantity FROM inventory where product_id = v_product_id AND 
 									  warehouse_id = v_warehouse_id AND seller_id = p_seller_id)
		INTO v_quantity;
 ELSE -- if the product is new to inventory
 SELECT p_quantity INTO v_quantity;
 END IF;
 --Insert the Product Delivery Record. 
 INSERT INTO Product_Delivery(Delivery_id, seller_id, product_id, warehouse_id, deliveryQuantity, Condition)
 VALUES(nextval('Product_Delivery_seq'), p_seller_id, v_product_id, v_warehouse_id, p_quantity, p_condition); 
 --Insert the Inventory Record
 INSERT INTO Inventory(product_id, warehouse_id, seller_id, quantity, condition)
 VALUES(v_product_id,v_warehouse_id, p_seller_id, v_quantity, p_condition); 
END; 
$$; 

-- New Customer Account Use Case --
CREATE OR REPLACE PROCEDURE NEW_CUSTOMER_ACCOUNT( 
 p_username IN VARCHAR,  -- new customer username
 p_address IN VARCHAR, -- Customer address
 p_phone IN VARCHAR, -- Customer Phone number. 
 p_email IN VARCHAR, -- Customer Email address. 
 p_first_name IN VARCHAR, -- Customer First name  
 p_last_name IN VARCHAR) -- Customer Last name
 LANGUAGE plpgsql 
AS $$ 
BEGIN 
 -- check if the username is unique
 IF p_username IN (select Username from Customer) THEN 
 RAISE EXCEPTION USING MESSAGE = 'This username is already used, please create a new one', 
 ERRCODE = 22000; 
 END IF;
 --Insert the Product Delivery Record. 
 INSERT INTO Customer(user_id, username, address, phone, email, firstName, lastName)
 VALUES(nextval('Customer_seq'), p_username, p_address, p_phone, p_email, p_first_name, p_last_name); 
END; 
$$;

-- Product Purchase Use Case --
CREATE OR REPLACE PROCEDURE PRODUCT_PURCHASE( 
 p_username IN VARCHAR,  -- username for customer
 p_product_name IN VARCHAR, -- Name of product purchased
 p_quantity IN NUMERIC, -- Quantity purchased
 p_shipping_speed IN VARCHAR,  -- Customer choice of shipping speed
 p_seller_name IN VARCHAR) -- Seller id
 LANGUAGE plpgsql 
AS $$ 
DECLARE 
 v_product_id DECIMAL(8); --Declare a variable to hold the ID of product 
 v_subTotal DECIMAL(12,2); --Declare a variable to hold the total amount purchased
 v_seller_id DECIMAL(8); --Declare a variable to hold the seller's id
 v_user_id DECIMAL(8); --Declare a variable to hold the user's id
BEGIN 
 -- get the product_id
 SELECT product_id INTO v_product_id FROM Product
 WHERE productName = p_product_name; 
  -- get the seller_id
 SELECT seller_id INTO v_seller_id FROM seller
 WHERE sellerName = p_seller_name; 
  -- get the user_id
 SELECT user_id INTO v_user_id FROM customer
 WHERE userName = p_username; 
 -- check if the purchase quantity is less than inventory
 IF p_quantity > (select Quantity from Inventory
				 where seller_id = v_seller_id and product_id = v_product_id) THEN 
 RAISE EXCEPTION USING MESSAGE = 'Purchase Quantity exceeds the product inventory', 
 ERRCODE = 22000; 
 END IF;
 -- Decrease the products inventory
 UPDATE Inventory SET Quantity = Quantity - p_quantity
 WHERE seller_id = v_seller_id AND product_id = v_product_id;
 -- Calculate the subtotal
 SELECT p_quantity * (select productPrice from product where product_id = v_product_id)
 INTO v_subTotal;
 --Insert the Purchase Order Record. 
 INSERT INTO PurchaseOrder(order_id, user_id, product_id, seller_id, quantity, SubTotal, shippingSpeed, TrackingNumber)
 VALUES(nextval('PurchaseOrder_seq'), v_user_id, v_product_id, v_seller_id, p_quantity, v_subTotal, p_shipping_speed, NULL); 
END; 
$$;


-- Product Shipment Use Case -- 
CREATE OR REPLACE PROCEDURE PRODUCT_SHIPMENT( 
 p_tracking_number IN VARCHAR,  -- Tracking id for the order
 p_order_id IN NUMERIC) -- Order number
 LANGUAGE plpgsql 
AS $$ 
BEGIN 
 -- Add tracking number to the order
 UPDATE PurchaseOrder SET TrackingNumber = p_tracking_number
 WHERE order_id = p_order_id;
END; 
$$;

-- New Seller Use Case --
CREATE OR REPLACE PROCEDURE NEW_SELLER( 
 p_seller_name IN VARCHAR,  -- Seller name
 p_email IN VARCHAR, -- Seller email
 p_phone IN VARCHAR) -- Seller Phone number
 LANGUAGE plpgsql 
AS $$ 
BEGIN 
 -- Add tracking number to the order
 INSERT INTO Seller (seller_id, sellerName, sellerEmail, sellerPhone)
 VALUES (nextval('seller_seq'), p_seller_name, p_email,p_phone);
END; 
$$;


------------------------------------------ INSERTS ------------------------------------------
--Replace this with the inserts necessary to populate your tables.
--Some of these inserts will come from executing the stored procedures.

-- Add new customer account
CALL NEW_CUSTOMER_ACCOUNT('wyx9677', '171 Washington st', '4708322767', 'wyx9677@163.com', 'Yuxiao','Wu');
CALL NEW_CUSTOMER_ACCOUNT('andy1999', '105 Colborne Rd', '6173824569', 'andy1999@gmail.com','Andy','Lu');
CALL NEW_CUSTOMER_ACCOUNT('Sharmen666', '171 West Lane Ave', '6175463187', 'Sharmen@gmail.com','Sharmen','Smith');		  
CALL NEW_CUSTOMER_ACCOUNT('James1980', '4001 Main st', '6143713485', 'James66@yahoo.com','James','Smith');			  
-- test same username error case
-- CALL NEW_CUSTOMER_ACCOUNT('andy1999', '658 High st', '7204586695', 'Andy666@yahoo.com','Andy','Jones');	

-- Add category
INSERT INTO Category (category_id, categoryName) VALUES (nextval('category_seq'), 'Electronics');
INSERT INTO Category (category_id, categoryName) VALUES (nextval('category_seq'), 'Food and Grocery');
INSERT INTO Category (category_id, categoryName) VALUES (nextval('category_seq'), 'Garden and Tools');
INSERT INTO Category (category_id, categoryName) VALUES (nextval('category_seq'), 'Pet Supplies');
INSERT INTO Category (category_id, categoryName) VALUES (nextval('category_seq'), 'Beauty and Health');
INSERT INTO Category (category_id, categoryName) VALUES (nextval('category_seq'), 'Clothing');
INSERT INTO Category (category_id, categoryName) VALUES (nextval('category_seq'), 'Movies, Music and Games');

-- Add Product 
CALL ADD_NEW_PRODUCT('Amazon Fire TV 43"', '279.99', 'Brilliant 4K entertainment - Bring movies and shows to life',
					'Electronics');
CALL ADD_NEW_PRODUCT('Sony BDP-BX370 Blu-ray Disc Player', '88.00', 'Enjoy fast, stable Wi-Fi even when streaming in HD',
					'Electronics');
CALL ADD_NEW_PRODUCT('Quick-Size Paper Towels', '38.74', 'Pack contains 16 Family Rolls of Bounty Quick Size paper towels, equal to 40 Regular Rolls',
					'Food and Grocery');
CALL ADD_NEW_PRODUCT('Knorr Sauce Mix Pasta', '33.43', 'Knorr Sauce Mix Pesto is a classic sauce that is perfect for pasta, meats and fish',
					'Food and Grocery');
CALL ADD_NEW_PRODUCT('Cesar Gourmet Wet Dog Food', '22.31', 'Contains one (1) 24 count case of 3.5 ounce easy peel trays of Cesar Wet Dog Food Poultry',
					'Pet Supplies');
CALL ADD_NEW_PRODUCT('Dove Deep Moisture Body Wash', '15.67', 'Moisturizing body wash that’s made with Microbiome Nutrient Serum to nourish skin and its microbiome',
					'Beauty and Health');
CALL ADD_NEW_PRODUCT('Under Armour Womens Play Up 3.0 Shorts', '85.44', 'Soft, lightweight knit construction delivers superior comfort & breathability',
					'Clothing');
CALL ADD_NEW_PRODUCT('adidas Originals Sneaker', '46.21', 'Plastic is a problem. Innovation is our solution.',
					'Clothing');
-- test add same product case
-- CALL ADD_NEW_PRODUCT('Quick-Size Paper Towels', '38.74', 'Pack contains 16 Family Rolls', 'Food and Grocery');

-- Add seller
CALL NEW_SELLER('Adidas Originals','adidasoffical@ads.com','18009829337');
CALL NEW_SELLER('Amazon Electronics',NULL,'18006259887');
CALL NEW_SELLER('Sony',NULL,'18002227669');
CALL NEW_SELLER('Dove','dove@doveinc.org','2174286616');
CALL NEW_SELLER('Under Armour',NULL,'18887276687');
CALL NEW_SELLER('Cesar',NULL,'0800738800');
CALL NEW_SELLER('Bounty','marketing@bounty.co.ke','254736293050');

-- Add warehouse
INSERT INTO Warehouse(warehouse_id, warehouseName, warehouseAddress, Manager)
VALUES(nextval('warehouse_seq'), 'PSP1','93308 Merle Haggard Dr, Bakersfield, CA 93308',NULL);
INSERT INTO Warehouse(warehouse_id, warehouseName, warehouseAddress, Manager)
VALUES(nextval('warehouse_seq'), 'DEN1','4303 Grinnell Blvd, Colorado Springs, CO 80925',NULL);
INSERT INTO Warehouse(warehouse_id, warehouseName, warehouseAddress, Manager)
VALUES(nextval('warehouse_seq'), 'BDL1','425 S Cherry St. Wallingford, CT 06492',NULL);
INSERT INTO Warehouse(warehouse_id, warehouseName, warehouseAddress, Manager)
VALUES(nextval('warehouse_seq'), 'MCO1','12340 Boggy Creek Rd, Orlando, FL 32824 (MCO1)',NULL);

-- Add inventory and product delivery record
CALL PRODUCT_DELIVERY(2, 'Sony BDP-BX370 Blu-ray Disc Player', 20, 'Brand New', 'PSP1');
CALL PRODUCT_DELIVERY(1, 'adidas Originals Sneaker', 500, 'Brand New', 'PSP1');
CALL PRODUCT_DELIVERY(4, 'Dove Deep Moisture Body Wash', 1000, 'Brand New', 'DEN1');
CALL PRODUCT_DELIVERY(5, 'Under Armour Womens Play Up 3.0 Shorts', 600, 'Brand New', 'BDL1');
CALL PRODUCT_DELIVERY(6, 'Cesar Gourmet Wet Dog Food', 200, 'Brand New', 'BDL1');
CALL PRODUCT_DELIVERY(7, 'Quick-Size Paper Towels', 500, 'Brand New', 'MCO1');
CALL PRODUCT_DELIVERY(3, 'Sony BDP-BX370 Blu-ray Disc Player', 100, 'Brand New', 'BDL1');
CALL PRODUCT_DELIVERY(2, 'Amazon Fire TV 43"', 100, 'Brand New', 'BDL1');
 
-- Add product purchase record 
CALL PRODUCT_PURCHASE('wyx9677', 'adidas Originals Sneaker',1,'standard shipping','Adidas Originals');
CALL PRODUCT_PURCHASE('wyx9677', 'Dove Deep Moisture Body Wash',2,'standard shipping','Dove');
CALL PRODUCT_PURCHASE('wyx9677', 'Amazon Fire TV 43"',1,'Two-day Shipping','Amazon Electronics');
CALL PRODUCT_PURCHASE('andy1999', 'Amazon Fire TV 43"',2,'Two-day Shipping','Amazon Electronics');
CALL PRODUCT_PURCHASE('James1980', 'Under Armour Womens Play Up 3.0 Shorts',10,'Overnight Shipping','Under Armour');
-- test purchase over inventory case
-- CALL PRODUCT_PURCHASE('andy1999', 'Cesar Gourmet Wet Dog Food',201,'standard shipping','Cesar');

-- Add product shippment
CALL PRODUCT_SHIPMENT('9400111202540848514287', 1);
CALL PRODUCT_SHIPMENT('EA599968241CN', 2);
CALL PRODUCT_SHIPMENT('9400112566481135486315', 4);

------------------------------------------ QUERIES ------------------------------------------
--Replace this with your queries.
SELECT productName, quantity, subtotal FROM PurchaseOrder
JOIN customer ON purchaseOrder.user_id = customer.user_id
JOIN product ON purchaseOrder.product_id = product.product_id
WHERE username = 'wyx9677';

SELECT productName, sellerName, SellerPhone, SellerEmail FROM Inventory
JOIN seller ON inventory.seller_id = seller.seller_id
JOIN product ON inventory.product_id = product.product_id
WHERE productName = 'adidas Originals Sneaker';

SELECT ProductName, WarehouseName, WarehouseAddress, Quantity FROM inventory
JOIN product ON inventory.product_id = product.product_id
JOIN warehouse ON inventory.warehouse_id = warehouse.warehouse_id
WHERE quantity < 100;

SELECT category.categoryName, COUNT(order_id) AS number_of_order 
FROM purchaseOrder
JOIN product ON purchaseOrder.product_id = product.product_id
JOIN category ON product.category_id = category.category_id
GROUP BY category.categoryName;

SELECT productName, quantity, condition FROM inventory
JOIN warehouse ON inventory.warehouse_id = warehouse.warehouse_id
JOIN product ON inventory.product_id = product.product_id
WHERE warehouseName = 'BDL1';
