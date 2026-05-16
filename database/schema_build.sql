-- =============================================================================
-- Vineyard parcel analysis: linking remote-sensing "missing area" estimates
-- to French AOC (PDO) regulations and attributes
-- =============================================================================

-- Load in spatial extension so ST functions can be used
INSTALL spatial;
LOAD spatial;

-- -----------------------------------------------------------------------------
-- area_missing
-- parcel level results from the missing-vine detection pipeline.
-- One row per parcel (IDU). CHECK constraints ensure physically sensible values
-- values: non-negative spacings/counts, percentage in [0, 100], as you cannnot
-- have found more vines than were expected.
-- -----------------------------------------------------------------------------
CREATE TABLE area_missing (
    IDU              VARCHAR PRIMARY KEY,                     -- parcel id
    row_spacing      DOUBLE  CHECK (row_spacing      >= 0),   -- meters betweeen rows of plants
    plant_spacing    DOUBLE  CHECK (plant_spacing    >= 0),   -- meters between plants
    rmse             DOUBLE  CHECK (rmse             >= 0),   -- RMSE of the model
    points_expected  DOUBLE  CHECK (points_expected  >= 0),   -- # of vines expected from results grid
    points_found     DOUBLE  CHECK (points_found     >= 0),   -- # of vines actually found
    area_missing_pct DOUBLE  CHECK (area_missing_pct BETWEEN 0 AND 100), -- percent of parcel without vines
    CHECK (points_found IS NULL OR points_expected IS NULL OR points_found <= points_expected)
);

INSERT INTO area_missing
SELECT * FROM read_csv('data/parcel_results.csv',
                       header = true,
                       nullstr = ['', 'NULL']);

-- -----------------------------------------------------------------------------
-- eu_pdo
-- Geometries of EU Protected Designation of Origin (PDO) zones.
-- The source file is in EPSG:3035, and we reproject to EPSG:2154 (standard French 
-- CRS) to allow joins against parcels
-- always_xy ensures (x, y) ordering
-- -----------------------------------------------------------------------------
CREATE TABLE eu_pdo (
    PDOid    VARCHAR(80) PRIMARY KEY,
    Shape    GEOMETRY
);

INSERT INTO eu_pdo
SELECT PDOid, ST_Transform(Shape, 'EPSG:3035', 'EPSG:2154', always_xy := true)
FROM ST_Read('data/EU_PDO.gpkg');

-- -----------------------------------------------------------------------------
-- aoc_regulations
-- Spacing regulations attributes of each PDO. In addition the name, administrative region,
-- wine region, and designation are atteached to each PDO using this data frame.
-- Checks that in each min/max pair the min is < the max.
-- -----------------------------------------------------------------------------
CREATE TABLE aoc_regulations (
    PDOid                 VARCHAR PRIMARY KEY,
    PDOnam                VARCHAR NOT NULL,
    Administrative_Region VARCHAR NOT NULL,
    Wine_Region           VARCHAR NOT NULL,
    Designation_Level     VARCHAR NOT NULL,
    min_row_spacing       DOUBLE  CHECK (min_row_spacing   > 0),
    max_row_spacing       DOUBLE  CHECK (max_row_spacing   > 0),
    min_plant_spacing     DOUBLE  CHECK (min_plant_spacing > 0),
    max_plant_spacing     DOUBLE  CHECK (max_plant_spacing > 0),
    max_area              DOUBLE  CHECK (max_area          > 0),
    source                VARCHAR,
    notes                 VARCHAR,
    CHECK (min_row_spacing   IS NULL OR max_row_spacing   IS NULL OR min_row_spacing   <= max_row_spacing),
    CHECK (min_plant_spacing IS NULL OR max_plant_spacing IS NULL OR min_plant_spacing <= max_plant_spacing),
    FOREIGN KEY (PDOid) REFERENCES eu_pdo(PDOid) 
);

INSERT INTO aoc_regulations
SELECT * FROM read_csv('data/aoc_regulations.csv',
                       header = true,
                       nullstr = ['', 'NULL']);

-- -----------------------------------------------------------------------------
-- parcels
-- Vineyard parcels with geometry, area, vine count, age, hierarchical land-use
-- classes (LEVEL.1..6), and per-grape-variety ("cepage") coverage columns.
-- Column names in the source file use dots (LEVEL.1, CEPAGE.MERLOT.N, ...),
-- which are converted into snake case.
-- The .N / .B suffixes indicate Noir (red) and Blanc (white) varieties.
-- -----------------------------------------------------------------------------
CREATE TABLE parcels AS
SELECT
    IDU,
    AREA                  AS area,
    SUP                   AS sup,
    "COUNT"               AS count_,
    AGE                   AS age,
    "LEVEL.1"             AS level_1,
    "LEVEL.2"             AS level_2,
    "LEVEL.3"             AS level_3,
    "LEVEL.4"             AS level_4,
    "LEVEL.5"             AS level_5,
    "LEVEL.6"             AS level_6,
    "CEPAGE.AUTRE"        AS cepage_autre,
    "CEPAGE.CABERNET.N"   AS cepage_cabernet_n,
    "CEPAGE.CALADOC.N"    AS cepage_caladoc_n,
    "CEPAGE.CARIGNAN.N"   AS cepage_carignan_n,
    "CEPAGE.CHARDONNAY.B" AS cepage_chardonnay_b,
    "CEPAGE.CINSAUT.N"    AS cepage_cinsaut_n,
    "CEPAGE.CLAIRETTE.B"  AS cepage_clairette_b,
    "CEPAGE.GAMAY.N"      AS cepage_gamay_n,
    "CEPAGE.GRENACHE.B"   AS cepage_grenache_b,
    "CEPAGE.GRENACHE.N"   AS cepage_grenache_n,
    "CEPAGE.MARSANNE.B"   AS cepage_marsanne_b,
    "CEPAGE.MARSELAN.N"   AS cepage_marselan_n,
    "CEPAGE.MERLOT.N"     AS cepage_merlot_n,
    "CEPAGE.MOURVEDRE.N"  AS cepage_mouvedre_n,
    "CEPAGE.MUSCAT.N"     AS cepage_muscat_n,
    "CEPAGE.ROUSSANNE.B"  AS cepage_roussanne_b,
    "CEPAGE.SAUVIGNON.B"  AS cepage_sauvignon_b,
    "CEPAGE.SYRAH.N"      AS cepage_syrah_n,
    "CEPAGE.UGNI.BLANC.B" AS cepage_ugni_blanc_b,
    "CEPAGE.VERMENTINO.B" AS cepage_vermentino_b,
    "CEPAGE.VIOGNIER.B"   AS cepage_viognier_b,
    geom                  AS geometry
FROM ST_Read('data/AllVDR.gpkg');

ALTER TABLE parcels ADD PRIMARY KEY (IDU);

-- -----------------------------------------------------------------------------
-- designation_priority
-- Lookup table mapping each Designation_Level to a numeric prestige tier so
-- we can sort/compare them. Higher tier = more prestigious.
--   5 = Grand Cru (top)
--   4 = Cru
--   3 = Communal (village-level)
--   2 = Sub-regional
--   1 = Regional (broadest)
-- -----------------------------------------------------------------------------
CREATE TABLE designation_priority (
    Designation_Level VARCHAR PRIMARY KEY,
    tier              INTEGER NOT NULL
);

INSERT INTO designation_priority VALUES
    ('Grand Cru', 5), ('Grand Cru Monopole', 5), ('Communal Grand Cru', 5),
    ('Cru', 4), ('Vin Doux Naturel Cru', 4), ('Sub-regional Cru', 4),
    ('Communal', 3), ('Communal Monopole', 3), ('Communal Vin Jaune', 3),
    ('VDN Communal', 3), ('Communal Rosé', 3), ('Communal Sparkling', 3),
    ('Communal Sweet', 3),
    ('Sub-regional', 2), ('VDN Sub-regional', 2), ('Sub-regional Rosé', 2),
    ('Sub-regional Sparkling', 2), ('Sub-regional Sweet', 2),
    ('Regional', 1), ('Regional Supérieur', 1), ('Crémant', 1),
    ('VDN Regional', 1), ('Vin Doux Naturel', 1), ('Vin de Liqueur', 1);

-- -----------------------------------------------------------------------------
-- parcel_aoc
-- PDOs are nested, meaning that a parcel can fall inside several differnet PDOs.
-- So for each parcel, only the single highest-tier PDO whose polygon contains
-- will be kept. This ensures that only the regulations of the most prestigious 
-- region will apply to a parcel.
--
-- Workflow:
--   1. Spatially join parcels to all intersecting PDOs.
--   2. Attach regulatory data using the PDOid.
--   3. ROW_NUMBER() ranks each parcel's matches by tier DESC
--   4. Keep only rn = 1 -> the top-tier PDO per parcel.
--
-- NULLS LAST ensures PDOs with an unknown Designation_Level lose to known ones.
-- -----------------------------------------------------------------------------
CREATE TABLE parcel_aoc AS
SELECT IDU, PDOid, PDOnam, Designation_Level, tier
FROM (
    SELECT
        p.IDU,
        e.PDOid,
        a.PDOnam,
        a.Designation_Level,
        dp.tier,
        ROW_NUMBER() OVER (
            PARTITION BY p.IDU
            ORDER BY dp.tier DESC NULLS LAST, e.PDOid
        ) AS rn
    FROM parcels p
    JOIN eu_pdo e
      ON ST_Intersects(p.geometry, e.Shape)
    JOIN aoc_regulations a
      ON a.PDOid = e.PDOid
    LEFT JOIN designation_priority dp
      ON dp.Designation_Level = a.Designation_Level
) ranked
WHERE rn = 1;
