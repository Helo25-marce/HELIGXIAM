# 📚 Documentation Base de Données
# Marketplace Microservices – HELIGXIAM

Auteur : Étudiant Keyce Informatique & IA  
Architecture : Microservices + API Gateway  
Bases utilisées : PostgreSQL + MongoDB  
Pattern : Database per Service  

---

# 🏗 1. Architecture Générale

## 🎯 Objectif
Séparer les responsabilités métier pour :
- scalabilité
- performance
- isolation des services
- cohérence transactionnelle

## 🧩 Choix technologique

| Type données | Technologie | Pourquoi |
|------------|------------|----------|
| Transactionnelles critiques | PostgreSQL | ACID, intégrité forte |
| Catalogue volumineux | MongoDB | recherche rapide, flexible |
| Panier temporaire | MongoDB | TTL, haute volumétrie |

---

# 🧠 2. Répartition par Service

| Service | Port | Base | Raison |
|---------|---------|-----------|-------------|
users | 3001 | PostgreSQL | comptes + sécurité |
orders | 3003 | PostgreSQL | transactions commandes |
payments | 3005 | PostgreSQL | audit légal |
addresses | 3006 | PostgreSQL | relations utilisateurs |
catalog | 3002 | MongoDB | recherche full-text |
cart | 3004 | MongoDB | données éphémères |

---

# 🗄 3. Partie SQL – PostgreSQL

## 📌 Schéma global

Users 1───∞ Orders  
Users 1───∞ Addresses  
Orders 1───∞ Order_Items  
Orders 1───1 Payments  

---

## 👤 3.1 Table USERS

Stocke les comptes authentifiés.

| Champ | Type | Description |
|--------|-----------|--------------|
id | UUID PK | identifiant utilisateur |
username | VARCHAR | unique |
email | VARCHAR | unique |
password_hash | VARCHAR | mot de passe hashé |
role | ENUM | client/vendeur/admin |
created_at | TIMESTAMP | création |
deleted_at | TIMESTAMP | soft delete |

Endpoints :
- /auth/*
- /users/*

---

## 🏠 3.2 Table ADDRESSES

Adresses livraison/facturation.

| Champ | Type |
|--------|-----------|
id | UUID PK |
user_id | FK → users |
type | billing/shipping |
line1 | VARCHAR |
line2 | VARCHAR |
city | VARCHAR |
postal_code | VARCHAR |
country | ISO code |
is_default | BOOLEAN |

Endpoints :
- /addresses

Relation :
User 1 → N Addresses

---

## 📦 3.3 Table ORDERS

Commandes utilisateur.

| Champ | Type |
|---------|--------------|
id | UUID PK |
user_id | FK |
shipping_address_id | FK |
billing_address_id | FK |
status | ENUM |
total_amount | DECIMAL |
currency | VARCHAR |
created_at | TIMESTAMP |

Endpoints :
- /orders
- /orders/:id
- /orders/status

---

## 🧾 3.4 Table ORDER_ITEMS

Snapshot produits d’une commande.

⚠ Pas de FK vers products (MongoDB)

| Champ | Type |
|---------|-------------|
id | UUID PK |
order_id | FK |
product_id | UUID (Mongo ref) |
name | VARCHAR |
price | DECIMAL |
quantity | INT |

Pourquoi snapshot ?
→ garder l’historique même si le produit change.

---

## 💳 3.5 Table PAYMENTS

Paiement unique par commande.

| Champ | Type |
|---------|-------------|
id | UUID PK |
order_id | FK UNIQUE |
provider | stripe/paypal |
status | pending/success/failed |
amount | DECIMAL |
transaction_id | VARCHAR |

Endpoints :
- /payments

Relation :
Order 1 → 1 Payment

---

# 🗂 4. Partie NoSQL – MongoDB

---

# 📚 4.1 Collection PRODUCTS (catalog-service)

Produits vendus.

## Structure

```json
{
  "productId": "uuid",
  "sellerId": "uuid",
  "name": "iPhone 15",
  "description": "Smartphone",
  "price": 1299.99,
  "currency": "EUR",
  "stock": 20,
  "categoryIds": ["uuid"],
  "images": ["url1.jpg"],
  "attributes": {
      "color": "black",
      "storage": "256GB"
  },
  "searchIndex": "iphone apple smartphone",
  "createdAt": ISODate()
}
