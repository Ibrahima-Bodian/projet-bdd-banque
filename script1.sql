-- Projet – Base de données bancaire

-- Section 1: Création de la base de données et connexion
DROP DATABASE IF EXISTS donneebancaire;
CREATE DATABASE donneebancaire;
\c donneebancaire;

-- Section 2: Création des tables

-- Table client
DROP TABLE IF EXISTS client CASCADE;
CREATE TABLE client (
    id_client INT PRIMARY KEY,
    nom VARCHAR(255),
    prenom VARCHAR(255),
    civilite VARCHAR(50),
    ddn DATE,
    adresse VARCHAR(255),
    cp VARCHAR(10),
    ville VARCHAR(255)
);

-- Table agent
DROP TABLE IF EXISTS agent CASCADE;
CREATE TABLE agent (
    matricule_agent INT PRIMARY KEY,
    nom_agent VARCHAR(255),
    ddn_agent DATE,
    civilite_agent VARCHAR(50)
);

-- Table compte
DROP TABLE IF EXISTS compte CASCADE;
CREATE TABLE compte (
    numcpt BIGINT PRIMARY KEY,  -- Modification ici
    designation_compte VARCHAR(255),
    date_rattachement DATE,
    type_rattachement VARCHAR(255),
    id_agent INT REFERENCES agent(matricule_agent)
);

-- Table mouvement
DROP TABLE IF EXISTS mouvement CASCADE;
CREATE TABLE mouvement (
    id_mouvement INT PRIMARY KEY,
    date_mouvement DATE,
    montant DECIMAL(10, 2),
    designation_mouvement VARCHAR(255),
    numcpt BIGINT REFERENCES compte(numcpt),  -- Modification ici
    concerne VARCHAR(255)
);

-- Table parrainage
DROP TABLE IF EXISTS parrainage CASCADE;
CREATE TABLE parrainage (
    id INT PRIMARY KEY,
    nom_parrain VARCHAR(200),
    date_parrainage DATE,
    id_client INT REFERENCES client(id_client),
    numcpt BIGINT REFERENCES compte(numcpt)  -- Modification ici
);

-- Table client_compte (table de jonction pour gérer les relations de plusieurs clients avec un compte)
DROP TABLE IF EXISTS client_compte CASCADE;
CREATE TABLE client_compte (
    id_client INT REFERENCES client(id_client),
    numcpt BIGINT REFERENCES compte(numcpt),  -- Modification ici
    PRIMARY KEY (id_client, numcpt)
);

-- Section 3: Création de la table intermédiaire pour l'importation des données

DROP TABLE IF EXISTS Banque CASCADE;
CREATE TABLE Banque (
    id_client INT,
    nom VARCHAR(250),
    prenom VARCHAR(250),
    civilite VARCHAR(250),
    ddn VARCHAR(250),
    adresse VARCHAR(400),
    cp VARCHAR(250),
    ville VARCHAR(250),
    date_rattachement VARCHAR(250),
    type_rattachement VARCHAR(250),
    numcpt BIGINT,  -- Modification ici
    designation_compte VARCHAR(250),
    id_mouvement INT,
    dt_mouvement VARCHAR(250),
    montant VARCHAR(250),
    designation_mouvement VARCHAR(250),
    parrain VARCHAR(250),
    date_parrainage VARCHAR(250),
    matricule_agent INT,
    nom_agent VARCHAR(250),
    ddn_agent VARCHAR(250),
    civilite_agent VARCHAR(250)
);

\copy Banque FROM 'C:/Users/ibrah/OneDrive/Documents/COURS SD1/BDD/SEM 2/Concept_Implementation_BDD/SAE/Projet/sae_donnees_bancaires.csv' DELIMITER ',' CSV HEADER;

-- Section 4: Insertion des données dans les tables relationnelles

-- Insertion dans client
INSERT INTO client (id_client, nom, prenom, civilite, ddn, adresse, cp, ville)
SELECT DISTINCT id_client, nom, prenom, civilite, ddn::DATE, adresse, cp, ville
FROM Banque
WHERE id_client IS NOT NULL;

-- Insertion dans agent
INSERT INTO agent (matricule_agent, nom_agent, ddn_agent, civilite_agent)
SELECT DISTINCT matricule_agent, nom_agent, ddn_agent::DATE, civilite_agent
FROM Banque
WHERE matricule_agent IS NOT NULL;

-- Insertion dans compte
INSERT INTO compte (numcpt, designation_compte, date_rattachement, type_rattachement, id_agent)
SELECT DISTINCT numcpt, designation_compte, date_rattachement::DATE, type_rattachement, 
(SELECT matricule_agent FROM agent WHERE matricule_agent = Banque.matricule_agent)
FROM Banque
WHERE numcpt IS NOT NULL;

-- Insertion dans mouvement
INSERT INTO mouvement (id_mouvement, date_mouvement, montant, designation_mouvement, numcpt, concerne)
SELECT DISTINCT id_mouvement, dt_mouvement::DATE, montant::DECIMAL, designation_mouvement, numcpt, concerne
FROM Banque
WHERE id_mouvement IS NOT NULL;

-- Insertion dans parrainage
INSERT INTO parrainage (id, nom_parrain, date_parrainage, id_client, numcpt)
SELECT DISTINCT id_mouvement AS id, parrain, date_parrainage::DATE, 
(SELECT id_client FROM client WHERE id_client = Banque.id_client), 
(SELECT numcpt FROM compte WHERE numcpt = Banque.numcpt)
FROM Banque
WHERE parrain IS NOT NULL;

-- Insertion dans client_compte
INSERT INTO client_compte (id_client, numcpt)
SELECT DISTINCT 
(SELECT id_client FROM client WHERE id_client = Banque.id_client), 
(SELECT numcpt FROM compte WHERE numcpt = Banque.numcpt)
FROM Banque
WHERE id_client IS NOT NULL AND numcpt IS NOT NULL;

-- Section 5: Création des vues

-- Vue clientcompte
CREATE VIEW clientcompte AS
SELECT c.id_client, c.nom, c.prenom, c.civilite, c.ddn, c.adresse, c.cp, c.ville, b.numcpt, b.designation_compte
FROM client AS c
JOIN client_compte AS cc ON c.id_client = cc.id_client
JOIN compte AS b ON cc.numcpt = b.numcpt;

-- Vue mouvementclient
CREATE VIEW mouvementclient AS
SELECT m.date_mouvement, m.montant, m.designation_mouvement, c.id_client, c.nom, c.prenom, c.civilite
FROM mouvement AS m
JOIN compte AS b ON m.numcpt = b.numcpt
JOIN client_compte AS cc ON b.numcpt = cc.numcpt
JOIN client AS c ON cc.id_client = c.id_client;

-- Vue parrainageclient
CREATE VIEW parrainageclient AS
SELECT p.nom_parrain, c.id_client AS client_id, c.nom AS client_nom, c.prenom AS client_prenom, p.date_parrainage
FROM parrainage AS p
JOIN client AS c ON p.id_client = c.id_client
JOIN compte AS b ON p.numcpt = b.numcpt;

-- Section 6: Export des vues

-- Export de vue_clients_comptes
CREATE VIEW vue_clients_comptes AS
SELECT c.nom AS nom_client, b.numcpt AS numero_compte, MAX(m.date_mouvement) AS date_dernier_mouvement, SUM(m.montant) AS solde_compte
FROM client AS c
JOIN client_compte AS cc ON c.id_client = cc.id_client
JOIN compte AS b ON cc.numcpt = b.numcpt
JOIN mouvement AS m ON b.numcpt = m.numcpt
WHERE m.date_mouvement < DATE_TRUNC('year', CURRENT_DATE) - INTERVAL '1 year' + INTERVAL '1 day'
GROUP BY c.nom, b.numcpt;

\COPY (SELECT * FROM vue_clients_comptes) TO 'C:/Users/ibrah/OneDrive/Documents/COURS SD1/BDD/SEM 2/Concept_Implementation_BDD/SAE/Projet/sae_donnees_bancaires1.csv' DELIMITER ',' CSV HEADER;

-- Export de vue_parrainage
CREATE VIEW vue_parrainage AS
SELECT a.nom_agent, p.nom_parrain, c.nom AS nom_client, p.date_parrainage, m.date_mouvement AS date_mouvement_parrainage
FROM agent AS a
JOIN parrainage AS p ON a.matricule_agent = p.id_client
JOIN client AS c ON p.id_client = c.id_client
JOIN compte AS b ON p.numcpt = b.numcpt
JOIN mouvement AS m ON b.numcpt = m.numcpt
WHERE p.date_parrainage >= DATE_TRUNC('year', CURRENT_DATE)
ORDER BY p.date_parrainage DESC;

\COPY (SELECT * FROM vue_parrainage) TO 'C:/Users/ibrah/OneDrive/Documents/COURS SD1/BDD/SEM 2/Concept_Implementation_BDD/SAE/Projet/sae_donnees_bancaires1.csv' DELIMITER ',' CSV HEADER;

-- Section 7: Connexion à la base de données postgres
\c donneebancaire;