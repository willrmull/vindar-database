# Vineyard Missing-Area Analysis

A spatial database linking vineyard parcels in France to their AOC (Appellation d'Origine Contrôlée) regulations and to per-parcel missing-vine estimates from a LiDAR-based detection pipeline.

## Purpose

The main goal of this project is to create a queryable spatial database that can be used to analyze the results of the [vinDAR](https://github.com/vinDAR-MEDS) pipeline. This is done by bringing together three otherwise disconnected sources of information about French vineyards:

- Per-parcel missing-area results from the vinDAR analysis
- EU Protected Designation of Origin (PDO) polygons defining the extent of each [appellation](https://en.wikipedia.org/wiki/Appellation_d%27origine_contr%C3%B4l%C3%A9e)
- Hand-compiled AOC regulations describing each appellation's designation level, row/plant spacing rules, and area limits

Together, these allow parcel level missing area estimates to be evaluated against the regulatory context of the appellation each parcel falls within.

## Repository structure

```text
├── README.md
├── requirements.txt           # Python dependencies
├── database/
│   └── schema_build.sql       # Builds the full database: tables, constraints, etc.
├── data/                      # Input data (not fully committed — see "Data access")
│   ├── parcel_results.csv     # Output from vinDAR repository
│   ├── EU_PDO.gpkg            # EU PDO (AOC) geometries
│   ├── aoc_regulations.csv    # Hand-compiled AOC regulatory attributes
│   └── AllVDR.gpkg            # Vineyard parcel geometries and attributes (restricted)
└── vindar-database.ipynb      # Runs schema_build.sql, returns a summary DataFrame
```

## Setup

This project uses Python and DuckDB with the `spatial` extension.

1. Clone the repository:
```bash
   git clone <repo-url>
   cd <repo-name>
```
2. Install dependencies (Python 3.10+ recommended):
```bash
   pip install -r requirements.txt
```
3. Place the required data files in the `data/` folder (see Data access below).
4. Open and run `vindar-database.ipynb`. It runs the SQL script to build the database and returns a summary table.
## Data access

Four input files are expected in the `data/` folder. Two are included in the repository, one is publicly downloadable, and one is restricted.

| File                  | Source                                                                            | Status                                 |
| --------------------- | --------------------------------------------------------------------------------- | -------------------------------------- |
| `parcel_results.csv`  | Output from the [vinDAR](https://github.com/vinDAR-MEDS) pipeline                 | Included in repo                       |
| `aoc_regulations.csv` | Hand-compiled from public AOC specifications                                      | Included in repo                       |
| `EU_PDO.gpkg`         | [figshare: Candiago et al. 2024](https://doi.org/10.6084/m9.figshare.25393261.v2) | Public — download and place in `data/` |
| `AllVDR.gpkg`         | Provided by project partners                                                      | **Restricted** — see alternative below |

**Public alternative for `AllVDR.gpkg`:** Vineyard parcel geometries can be obtained from the French [Registre Parcellaire Graphique (RPG)](https://geoservices.ign.fr/rpg), filtering for vineyard land-use codes. The schema and column names in `schema_build.sql` assume the structure of `AllVDR.gpkg`, so minor edits to the query in the SQL script are likely to be required when substituting RPG data.

## References & acknowledgements

- **vinDAR-MEDS** — companion LiDAR-based detection pipeline.
  <https://github.com/vinDAR-MEDS>
- **EU PDO geometries** —
  Candiago, S., Tscholl, S., Bassani, L., Fraga, H., & Egarter Vigl, L. (2024). *Quality wines in Italy and France: a dataset of protected designation of origin specifications* [Data set]. figshare. <https://doi.org/10.6084/m9.figshare.25393261.v2>
- **LiDAR source data** (underlying the vinDAR detection pipeline) —
  Institut national de l'information géographique et forestière. (2026). *LiDAR HD Point Clouds* [Data set]. (Original work published 2024). <http://data.europa.eu/88u/dataset/ignf_nuages-de-points-lidar-hd>
- **DuckDB** and the **`spatial`** extension. <https://duckdb.org/>
- Developed for **EDS 213: Databases and Data Management**, Bren School of Environmental Science & Management, UC Santa Barbara.

## License

This project is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
