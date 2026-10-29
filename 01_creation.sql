-- ============================================================
-- Projet : Base de données e-commerce Olist (Brésil)
-- Fichier : 01_creation.sql
-- Objectif : Création des 9 tables du schéma, dans l'ordre
--            des dépendances de clés étrangères
-- SGBD : PostgreSQL
-- ============================================================

-- --------------------------------------------------------------
-- Table : customers
-- Remarque : customer_id identifie une commande passée par un
-- client, alors que customer_unique_id identifie le client réel
-- (répétable si le client repasse commande). C'est donc bien
-- customer_id qui sert de clé primaire ici.
-- --------------------------------------------------------------
CREATE TABLE customers (
    customer_id VARCHAR PRIMARY KEY,
    customer_unique_id VARCHAR NOT NULL,
    customer_zip_code_prefix VARCHAR,
    customer_city VARCHAR NOT NULL,
    customer_state VARCHAR NOT NULL
);

-- --------------------------------------------------------------
-- Table : sellers
-- --------------------------------------------------------------
CREATE TABLE sellers (
    seller_id VARCHAR PRIMARY KEY,
    seller_zip_code_prefix VARCHAR NOT NULL,
    seller_city VARCHAR NOT NULL,
    seller_state VARCHAR NOT NULL
);

-- --------------------------------------------------------------
-- Table : geolocation
-- Remarque : geolocation_zip_code_prefix n'est PAS unique
-- (plusieurs coordonnées GPS peuvent partager un même préfixe),
-- et le dataset contient des lignes strictement dupliquées.
-- => clé primaire artificielle (SERIAL) plutôt qu'une clé
--    naturelle ou composite.
-- --------------------------------------------------------------

CREATE TABLE geolocation (
    id SERIAL PRIMARY KEY,
    geolocation_zip_code_prefix VARCHAR NOT NULL,
    geolocation_lat NUMERIC NOT NULL,
    geolocation_lng NUMERIC NOT NULL,
    geolocation_city VARCHAR NOT NULL,
    geolocation_state VARCHAR NOT NULL
);

--Verification de la table
SELECT * FROM geolocation;

--Affichage des premières lignes
SELECT * FROM geolocation LIMIT 10;

--Verification de doublons
SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, COUNT(*)
FROM geolocation
GROUP BY geolocation_zip_code_prefix, geolocation_lat, geolocation_lng
HAVING COUNT(*) > 1;

-- --------------------------------------------------------------
-- Table : product_category_name_translation
-- Remarque : product_category_name (en portugais) est la clé
-- primaire ; product_category_name_english est la traduction.
-- Cette table doit être créée AVANT products, car products.
-- product_category_name la référence (FOREIGN KEY).

CREATE TABLE product_category_name_translation (
	product_category_name VARCHAR PRIMARY KEY,
	product_category_name_english VARCHAR
);

-- verification des valeurs manquantes
SELECT COUNT(*)
FROM product_category_name_translation
WHERE product_category_name IS NULL;

-- --------------------------------------------------------------
-- Table : products
-- Remarque : product_weight_g laissé nullable après vérification
-- que la colonne n'était pas garantie remplie pour toutes les
-- lignes du CSV.
-- --------------------------------------------------------------
CREATE TABLE products (
	product_id VARCHAR PRIMARY KEY,
	product_category_name VARCHAR REFERENCES product_category_name_translation(product_category_name),
	product_name_lenght INTEGER,
	product_description_lenght INTEGER,
	product_photos_qty INTEGER,
	product_weight_g INTEGER,
	product_length_cm INTEGER,
	product_height_cm INTEGER,
	product_width_cm INTEGER
);

-- NOTE HISTORIQUE : à l'import, 2 catégories présentes dans products.csv
-- n'existaient pas dans product_category_name_translation
-- ('pc_gamer' et 'portateis_cozinha_e_preparadores_de_alimentos').

--Retrait de la clé étrangère car toutes les catégories dans la table products n'ont pas de correspondance dans la table référencée
ALTER TABLE products DROP CONSTRAINT products_product_category_name_fkey;

--Affichage des premières lignes
SELECT * FROM products LIMIT 10;

--Affichage de toutes les categories sans correspondance dans product_category_name_translation
SELECT DISTINCT product_category_name 
FROM products 
WHERE product_category_name NOT IN (SELECT product_category_name_translation.product_category_name 
FROM product_category_name_translation );

--Ajout des catégories manquantes à la table product_category_name_translation
INSERT INTO product_category_name_translation (product_category_name, product_category_name_english)
VALUES ('portateis_cozinha_e_preparadores_de_alimentos', 'Kitchen Appliances & Food Prep'),
('pc_gamer', 'pc_gamer');

--Ajout de la clé étangère à la table products
ALTER TABLE products 
ADD CONSTRAINT  products_product_category_name_fkey
FOREIGN KEY (product_category_name) REFERENCES product_category_name_translation(product_category_name);

-- --------------------------------------------------------------
-- Table : orders
-- --------------------------------------------------------------
CREATE TABLE orders (
	order_id VARCHAR PRIMARY KEY,
	customer_id VARCHAR REFERENCES customers (customer_id),
	order_status VARCHAR,
	order_purchase_timestamp TIMESTAMP,
	order_approved_at TIMESTAMP,
	order_delivered_carrier_date TIMESTAMP,
	order_delivered_customer_date TIMESTAMP,
	order_estimated_delivery_date TIMESTAMP
);

-- --------------------------------------------------------------
-- Table : order_items
-- Remarque : order_item_id est un numéro de ligne au sein d'une
-- commande (pas un identifiant unique global). Clé primaire
-- composite : (order_id, order_item_id). La cle composite permet d''identifier un item d''une commande specifique
-- --------------------------------------------------------------

CREATE TABLE order_items (
	order_id VARCHAR NOT NULL REFERENCES orders(order_id),
	order_item_id INTEGER NOT NULL,
	product_id VARCHAR NOT NULL REFERENCES products(product_id),
	seller_id VARCHAR NOT NULL REFERENCES sellers(seller_id),
	shipping_limit_date TIMESTAMP,
	price NUMERIC NOT NULL,
	freight_value NUMERIC NOT NULL,
	PRIMARY KEY (order_id, order_item_id)
);

SELECT * FROM order_items LIMIT 10;

-- --------------------------------------------------------------
-- Table : order_payments
-- Remarque : une commande peut avoir plusieurs lignes de paiement
-- (paiement en plusieurs fois, ou plusieurs moyens de paiement
-- combinés). Clé primaire composite : (order_id, payment_sequential).
-- --------------------------------------------------------------
CREATE TABLE order_payments (
order_id VARCHAR NOT NULL REFERENCES orders(order_id),
payment_sequential INTEGER NOT NULL,
payment_type VARCHAR NOT NULL,
payment_installments INTEGER NOT NULL,
payment_value NUMERIC NOT NULL,
PRIMARY KEY (order_id, payment_sequential)
);

-- --------------------------------------------------------------
-- Table : order_reviews
-- Remarque : review_id seul n'était pas garanti unique dans le
-- dataset. Vérification effectuée après import :
--   SELECT review_id, COUNT(*) FROM order_reviews
--   GROUP BY review_id HAVING COUNT(*) > 1;
-- => Clé primaire composite (review_id, order_id) ajoutée après
--    import, une fois l'unicité de cette combinaison confirmée.
-- --------------------------------------------------------------
CREATE TABLE order_reviews (
	review_id VARCHAR,
	order_id VARCHAR NOT NULL REFERENCES orders(order_id),
	review_score INTEGER NOT NULL,
	review_comment_title VARCHAR,
	review_comment_message VARCHAR,
	review_creation_date TIMESTAMP,
	review_answer_timestamp TIMESTAMP
);

--Verfication de l'unicite de review_id
SELECT review_id, COUNT(*)
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

--Ajout de la cle composite
ALTER TABLE order_reviews 
ADD CONSTRAINT order_reviews_pkey
PRIMARY KEY (review_id, order_id);

-- ============================================================
-- FIN DU SCRIPT DE CRÉATION
