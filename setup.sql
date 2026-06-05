-- =============================================================
-- setup.sql  –  JBS ハンズオン 事前セットアップ
--
-- 対象ノートブック: part1_snowflake_basics.ipynb (NB1)
--                  part2_cortex_ai.ipynb (NB2)
--
-- ============================================================
-- ⚠️  ワークスペース名の設定
--    ワークスペース名を変更した場合は下記の 2 行を同じ名前に更新してください
--    （Snowsight の Cmd+H / Ctrl+H で一括置換が便利です）
--
--    変更箇所：
--      Step 0 の LIST コマンド（3 か所）
--      Step 2 の COPY FILES コマンド（1 か所）
--
--    ワークスペース名（現在の設定）:
--      Snowflake_handson_basic_ai
-- ============================================================
--
-- 【実行前に必ず以下の事前準備を完了してください】
--
-- [1] GitHub からファイルをダウンロード
--     https://github.com/hilasnow/Snowflake_handson_basic_ai
--     「Code」>「Download ZIP」で一括ダウンロードして展開
--
-- [2] Snowsight でワークスペースを新規作成
--     ワークスペース名は必ず「Snowflake_handson_basic_ai」にしてください
--     （別の名前にすると Step 0 のファイルチェックと Step 2 のコピーが失敗します）
--
-- [3] CoCo の「+ 新規追加」>「ファイルをアップロード」で展開した ZIP 内の
--     全ファイル（ノートブック・SQL・data/ フォルダ）をアップロード
--
-- [4] この setup.sql を開いて全体を選択し一括実行
--     Step 0 で必須ファイルの存在を確認し、不足の場合はセッションを停止します
-- =============================================================

-- -----------------------------------------------
-- Step 0. 前提確認（アップロード必須ファイルの存在チェック）
-- -----------------------------------------------
USE ROLE ACCOUNTADMIN;

-- [0-1] CSVデータの確認（data/customers.csv）
LIST 'snow://workspace/USER$.PUBLIC."Snowflake_handson_basic_ai"/versions/live/data/customers.csv';
SELECT IFF(
    COUNT(*) = 0,
    SYSTEM$ABORT_SESSION(),
    '✅ [1/3] data/customers.csv を確認しました。'
) AS check_csv
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- [0-2] 仕入先商品データの確認（data/supplier_products_v2.csv）
LIST 'snow://workspace/USER$.PUBLIC."Snowflake_handson_basic_ai"/versions/live/data/supplier_products_v2.csv';
SELECT IFF(
    COUNT(*) = 0,
    SYSTEM$ABORT_SESSION(),
    '✅ [2/3] data/supplier_products_v2.csv を確認しました。'
) AS check_supplier
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- [0-3] 音声ログの確認（data/voice_logs/）
LIST 'snow://workspace/USER$.PUBLIC."Snowflake_handson_basic_ai"/versions/live/data/voice_logs/';
SELECT IFF(
    COUNT(*) = 0,
    SYSTEM$ABORT_SESSION(),
    '✅ [3/3] data/voice_logs/ を確認しました。セットアップを続行します。'
) AS check_voice
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- -----------------------------------------------
-- Step 1. ウェアハウス作成
-- -----------------------------------------------
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE WAREHOUSE IF NOT EXISTS AI_HANDSON_WH
    WAREHOUSE_SIZE      = 'xsmall'
    WAREHOUSE_TYPE      = 'standard'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE AI_HANDSON_WH;

-- -----------------------------------------------
-- Step 2. データベース・スキーマ・ステージ作成
-- -----------------------------------------------
CREATE OR REPLACE DATABASE AI_HANDSON_DB;
CREATE OR REPLACE SCHEMA AI_HANDSON_DB.ANALYTICS;
USE SCHEMA AI_HANDSON_DB.ANALYTICS;

CREATE OR REPLACE STAGE DATA_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY  = (ENABLE = TRUE);

-- ワークスペースの data/ フォルダをステージへコピー（CSV・JSON・音声・画像を一括）
COPY FILES INTO @DATA_STAGE
FROM 'snow://workspace/USER$.PUBLIC."Snowflake_handson_basic_ai"/versions/live/'
PATTERN = 'data/.*';

ALTER STAGE DATA_STAGE REFRESH;

-- -----------------------------------------------
-- Step 3. ファイルフォーマット作成
-- -----------------------------------------------
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE                     = 'CSV'
    SKIP_HEADER              = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"';

CREATE OR REPLACE FILE FORMAT json_format
    TYPE              = 'JSON'
    STRIP_OUTER_ARRAY = TRUE;

-- -----------------------------------------------
-- Step 4. テーブル作成
-- -----------------------------------------------
CREATE OR REPLACE TABLE dim_customers (
    customer_id       VARCHAR PRIMARY KEY,
    email             VARCHAR,
    phone             VARCHAR,
    last_name         VARCHAR,
    first_name        VARCHAR,
    gender            VARCHAR,
    birth_date        DATE,
    postal_code       VARCHAR,
    prefecture        VARCHAR,
    city              VARCHAR,
    address           VARCHAR,
    registration_date DATE,
    membership_tier   VARCHAR,
    total_orders      INTEGER,
    total_spent       DECIMAL(12,2),
    last_order_date   DATE,
    email_opt_in      BOOLEAN,
    app_installed     BOOLEAN
);

CREATE OR REPLACE TABLE dim_products (
    product_id      VARCHAR PRIMARY KEY,
    product_name    VARCHAR,
    product_name_en VARCHAR,
    category_l1     VARCHAR,
    category_l2     VARCHAR,
    category_l3     VARCHAR,
    brand           VARCHAR,
    supplier_id     VARCHAR,
    cost_price      DECIMAL(10,2),
    list_price      DECIMAL(10,2),
    current_price   DECIMAL(10,2),
    stock_quantity  INTEGER,
    product_status  VARCHAR,
    launch_date     DATE,
    description     TEXT,
    weight_g        INTEGER,
    dimensions      VARCHAR
);

CREATE OR REPLACE TABLE fact_orders (
    order_id            VARCHAR PRIMARY KEY,
    order_datetime      TIMESTAMP,
    customer_id         VARCHAR,
    product_id          VARCHAR,
    quantity            INTEGER,
    unit_price          DECIMAL(10,2),
    discount_amount     DECIMAL(10,2),
    tax_amount          DECIMAL(10,2),
    total_amount        DECIMAL(10,2),
    payment_method      VARCHAR,
    shipping_address_id VARCHAR,
    order_channel       VARCHAR,
    campaign_id         VARCHAR,
    order_status        VARCHAR
);

CREATE OR REPLACE TABLE raw_sns_mentions (
    post_id            VARCHAR PRIMARY KEY,
    platform           VARCHAR,
    post_type          VARCHAR,
    username           VARCHAR,
    display_name       VARCHAR,
    content            VARCHAR,
    posted_at          TIMESTAMP,
    likes              INTEGER,
    retweets           INTEGER,
    replies            INTEGER,
    hashtags           ARRAY,
    mentioned_products ARRAY,
    media_urls         ARRAY
);

CREATE OR REPLACE TABLE raw_voice_logs (
    call_id           VARCHAR PRIMARY KEY,
    scenario_id       VARCHAR,
    audio_file        VARCHAR,
    call_duration_sec NUMBER(10,2),
    call_start_time   TIMESTAMP,
    call_end_time     TIMESTAMP,
    category          VARCHAR,
    agent_id          VARCHAR,
    customer_phone    VARCHAR,
    customer_id       VARCHAR,
    call_type         VARCHAR,
    transcribed_text  TEXT
);

CREATE OR REPLACE TABLE raw_ad_creatives (
    creative_id     VARCHAR PRIMARY KEY,
    creative_name   VARCHAR,
    image_file_path VARCHAR,
    target_segment  VARCHAR,
    impressions     INTEGER,
    clicks          INTEGER,
    conversions     INTEGER,
    spend           DECIMAL(10,2)
);

CREATE OR REPLACE TABLE supplier_products_v2 (
    supplier_product_id   VARCHAR PRIMARY KEY,
    supplier_product_name VARCHAR,
    supplier_name         VARCHAR,
    supplier_price        DECIMAL(10,2),
    supplier_category     VARCHAR,
    original_product_id   VARCHAR  -- 正解データ（Part2 精度検証用）
);

-- -----------------------------------------------
-- Step 5. データロード（CSV / JSON）
-- -----------------------------------------------
COPY INTO dim_customers         FROM @DATA_STAGE/data/customers.csv          FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO dim_products          FROM @DATA_STAGE/data/products.csv           FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO fact_orders           FROM @DATA_STAGE/data/orders.csv             FILE_FORMAT = (FORMAT_NAME = csv_format);
-- ad_creatives.csv（EC系）はロードしない（金融シナリオでは不使用）
COPY INTO raw_ad_creatives      FROM @DATA_STAGE/data/fin_ad_creatives.csv   FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO supplier_products_v2  FROM @DATA_STAGE/data/supplier_products_v2.csv FILE_FORMAT = (FORMAT_NAME = csv_format) ON_ERROR = 'CONTINUE';

INSERT INTO raw_sns_mentions (post_id, platform, post_type, username, display_name,
    content, posted_at, likes, retweets, replies, hashtags, mentioned_products, media_urls)
SELECT $1:post_id::VARCHAR, $1:platform::VARCHAR, $1:post_type::VARCHAR,
    $1:username::VARCHAR, $1:display_name::VARCHAR, $1:content::VARCHAR,
    $1:posted_at::TIMESTAMP, $1:likes::INTEGER, $1:retweets::INTEGER,
    $1:replies::INTEGER, $1:hashtags::ARRAY, $1:mentioned_products::ARRAY, $1:media_urls::ARRAY
FROM @DATA_STAGE/data/sns_logs.json (FILE_FORMAT => json_format);

INSERT INTO raw_voice_logs (call_id, scenario_id, audio_file, call_duration_sec,
    call_start_time, call_end_time, category, agent_id, customer_phone, customer_id, call_type)
SELECT $1:call_id::VARCHAR, $1:scenario_id::VARCHAR, $1:audio_file::VARCHAR,
    $1:call_duration_sec::NUMBER(10,2), $1:call_start_time::TIMESTAMP,
    $1:call_end_time::TIMESTAMP, $1:category::VARCHAR, $1:agent_id::VARCHAR,
    $1:customer_phone::VARCHAR, $1:customer_id::VARCHAR, $1:call_type::VARCHAR
FROM @DATA_STAGE/data/voice_logs/voice_logs_metadata.json (FILE_FORMAT => json_format);

-- -----------------------------------------------
-- Step 6. AI_TRANSCRIBE（音声→テキスト）
-- -----------------------------------------------
MERGE INTO raw_voice_logs AS target
USING (
    SELECT
        SPLIT_PART(relative_path, '/', -1) AS file_name,
        AI_TRANSCRIBE(TO_FILE('@DATA_STAGE', relative_path)):text::TEXT AS transcribed_text
    FROM DIRECTORY(@DATA_STAGE)
    WHERE REGEXP_LIKE(relative_path, 'data/voice_logs.*\\.mp3', 'i')
) AS source
ON target.audio_file = source.file_name
WHEN MATCHED THEN UPDATE SET target.transcribed_text = source.transcribed_text;

-- -----------------------------------------------
-- Step 7. セットアップ確認
-- 各テーブルの件数が 0 の場合はデータロードに失敗しています。
-- raw_ad_creatives は FIN- プレフィックスのデータが 64 件入っていれば OK。
-- -----------------------------------------------
SELECT 'dim_customers'    AS table_name, COUNT(*) AS row_count FROM dim_customers    UNION ALL
SELECT 'dim_products'     AS table_name, COUNT(*) AS row_count FROM dim_products     UNION ALL
SELECT 'fact_orders'      AS table_name, COUNT(*) AS row_count FROM fact_orders      UNION ALL
SELECT 'raw_sns_mentions' AS table_name, COUNT(*) AS row_count FROM raw_sns_mentions UNION ALL
SELECT 'raw_voice_logs'   AS table_name, COUNT(*) AS row_count FROM raw_voice_logs   UNION ALL
SELECT 'raw_ad_creatives' AS table_name, COUNT(*) AS row_count FROM raw_ad_creatives
ORDER BY table_name;

-- raw_ad_creatives の内訳確認（FIN- データのみ 64 件であること）
SELECT
    COUNT(*)                                        AS total_rows,
    COUNT(CASE WHEN creative_id LIKE 'FIN-%' THEN 1 END) AS fin_rows,
    COUNT(CASE WHEN creative_id NOT LIKE 'FIN-%' THEN 1 END) AS other_rows
FROM raw_ad_creatives;