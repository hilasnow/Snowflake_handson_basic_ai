-- =============================================================
-- setup.sql  –  JBS ハンズオン 事前セットアップ
--
-- 対象ノートブック: part1_snowflake_basics.ipynb (NB1)
--                  part2_cortex_ai.ipynb (NB2)
-- データ         : data/ フォルダ内の CSV / JSON / PDF / 音声ファイル
--                  → このリポジトリの data/ に同梱
-- =============================================================

-- ===============================================================
-- !! Step 0 (事前作業) ファイルのアップロード !!
--
-- このスクリプトを実行する前に、以下の手順でファイルをアップロードしてください。
-- ※ ファイルがない状態で実行するとデータが空のまま終了します。
--
-- 1. リポジトリの data/ フォルダをローカルにダウンロード
--    https://github.com/hilasnow/Snowflake_handson_basic_ai
--
-- 2. setup.sql の Step 1〜3 を先に実行（DB・WH・ステージを作成）
--
-- 3. Snowsight で DATA_STAGE にファイルをアップロード:
--    左メニュー > Data > Databases > GLACIERSTYLE_DB
--    > EC_ANALYTICS_SCHEMA > Stages > DATA_STAGE を開く
--    右上の「+ Files」ボタンから data/ 内の全ファイルを選択
--    （CSV / JSON / PDF / voice_logs/*.mp3 をすべてアップロード）
--
-- 4. アップロード確認後、Step 4 以降を実行
-- ===============================================================

-- -----------------------------------------------
-- Step 1. 環境設定
-- -----------------------------------------------
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE WAREHOUSE IF NOT EXISTS GLACIERSTYLE_WH
    WAREHOUSE_SIZE      = 'xsmall'
    WAREHOUSE_TYPE      = 'standard'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE GLACIERSTYLE_WH;

-- -----------------------------------------------
-- Step 2. データベース・スキーマ
-- -----------------------------------------------
CREATE OR REPLACE DATABASE GLACIERSTYLE_DB;
CREATE OR REPLACE SCHEMA GLACIERSTYLE_DB.EC_ANALYTICS_SCHEMA;
USE SCHEMA GLACIERSTYLE_DB.EC_ANALYTICS_SCHEMA;

-- -----------------------------------------------
-- Step 3. ステージ作成
-- -----------------------------------------------
CREATE OR REPLACE STAGE DATA_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY  = (ENABLE = TRUE);

-- !! ここで一旦止めてファイルをアップロードしてください（Step 0 参照）!!

-- -----------------------------------------------
-- Step 4. ステージ更新（アップロード後に実行）
-- -----------------------------------------------
ALTER STAGE DATA_STAGE REFRESH;

-- -----------------------------------------------
-- Step 5. ファイルフォーマット作成
-- -----------------------------------------------
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE                     = 'CSV'
    SKIP_HEADER              = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"';

CREATE OR REPLACE FILE FORMAT json_format
    TYPE              = 'JSON'
    STRIP_OUTER_ARRAY = TRUE;

-- -----------------------------------------------
-- Step 6. テーブル作成
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

CREATE OR REPLACE TABLE fact_payments (
    payment_id         VARCHAR PRIMARY KEY,
    order_id           VARCHAR,
    payment_datetime   TIMESTAMP,
    card_brand         VARCHAR,
    card_last4         VARCHAR,
    payment_amount     DECIMAL(10,2),
    authorization_code VARCHAR,
    payment_status     VARCHAR,
    fraud_score        DECIMAL(5,2),
    device_fingerprint VARCHAR,
    ip_address         VARCHAR,
    billing_country    VARCHAR
);

CREATE OR REPLACE TABLE fact_web_logs (
    log_id          VARCHAR PRIMARY KEY,
    session_id      VARCHAR,
    customer_id     VARCHAR,
    event_timestamp TIMESTAMP,
    event_type      VARCHAR,
    page_url        VARCHAR,
    page_category   VARCHAR,
    referrer_url    VARCHAR,
    utm_source      VARCHAR,
    utm_medium      VARCHAR,
    utm_campaign    VARCHAR,
    device_type     VARCHAR,
    browser         VARCHAR,
    os              VARCHAR,
    time_on_page    INTEGER,
    product_id      VARCHAR
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
    campaign_id     VARCHAR,
    creative_name   VARCHAR,
    creative_type   VARCHAR,
    image_file_path VARCHAR,
    copy_text       TEXT,
    headline        VARCHAR,
    cta_text        VARCHAR,
    target_segment  VARCHAR,
    platform        VARCHAR,
    start_date      DATE,
    end_date        DATE,
    impressions     INTEGER,
    clicks          INTEGER,
    conversions     INTEGER,
    spend           DECIMAL(10,2)
);

-- -----------------------------------------------
-- Step 7. データロード（CSV / JSON）
-- -----------------------------------------------
COPY INTO dim_customers    FROM @DATA_STAGE/customers.csv     FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO dim_products     FROM @DATA_STAGE/products.csv      FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO fact_orders      FROM @DATA_STAGE/orders.csv        FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO fact_payments    FROM @DATA_STAGE/payments.csv      FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO raw_ad_creatives FROM @DATA_STAGE/ad_creatives.csv  FILE_FORMAT = (FORMAT_NAME = csv_format);

INSERT INTO fact_web_logs (log_id, session_id, customer_id, event_timestamp, event_type,
    page_url, page_category, referrer_url, utm_source, utm_medium, utm_campaign,
    device_type, browser, os, time_on_page, product_id)
SELECT $1:log_id::VARCHAR, $1:session_id::VARCHAR, $1:customer_id::VARCHAR,
    $1:event_timestamp::TIMESTAMP, $1:event_type::VARCHAR, $1:page_url::VARCHAR,
    $1:page_category::VARCHAR, $1:referrer_url::VARCHAR, $1:utm_source::VARCHAR,
    $1:utm_medium::VARCHAR, $1:utm_campaign::VARCHAR, $1:device_type::VARCHAR,
    $1:browser::VARCHAR, $1:os::VARCHAR, $1:time_on_page::VARCHAR, $1:product_id::VARCHAR
FROM @DATA_STAGE/web_logs.json (FILE_FORMAT => json_format);

INSERT INTO raw_sns_mentions (post_id, platform, post_type, username, display_name,
    content, posted_at, likes, retweets, replies, hashtags, mentioned_products, media_urls)
SELECT $1:post_id::VARCHAR, $1:platform::VARCHAR, $1:post_type::VARCHAR,
    $1:username::VARCHAR, $1:display_name::VARCHAR, $1:content::VARCHAR,
    $1:posted_at::TIMESTAMP, $1:likes::INTEGER, $1:retweets::INTEGER,
    $1:replies::INTEGER, $1:hashtags::ARRAY, $1:mentioned_products::ARRAY, $1:media_urls::ARRAY
FROM @DATA_STAGE/sns_logs.json (FILE_FORMAT => json_format);

INSERT INTO raw_voice_logs (call_id, scenario_id, audio_file, call_duration_sec,
    call_start_time, call_end_time, category, agent_id, customer_phone, customer_id, call_type)
SELECT $1:call_id::VARCHAR, $1:scenario_id::VARCHAR, $1:audio_file::VARCHAR,
    $1:call_duration_sec::NUMBER(10,2), $1:call_start_time::TIMESTAMP,
    $1:call_end_time::TIMESTAMP, $1:category::VARCHAR, $1:agent_id::VARCHAR,
    $1:customer_phone::VARCHAR, $1:customer_id::VARCHAR, $1:call_type::VARCHAR
FROM @DATA_STAGE/voice_logs/voice_logs_metadata.json (FILE_FORMAT => json_format);

-- -----------------------------------------------
-- Step 8. AI_TRANSCRIBE（音声→テキスト）
-- -----------------------------------------------
MERGE INTO raw_voice_logs AS target
USING (
    SELECT
        SPLIT_PART(relative_path, '/', -1) AS file_name,
        AI_TRANSCRIBE(TO_FILE('@DATA_STAGE', relative_path)):text::TEXT AS transcribed_text
    FROM DIRECTORY(@DATA_STAGE)
    WHERE REGEXP_LIKE(relative_path, 'voice_logs.*\\.mp3', 'i')
) AS source
ON target.audio_file = source.file_name
WHEN MATCHED THEN UPDATE SET target.transcribed_text = source.transcribed_text;

-- -----------------------------------------------
-- Step 9. AI_PARSE_DOCUMENT（PDF→構造化）
-- -----------------------------------------------
CREATE OR REPLACE TABLE raw_faq_documents AS
WITH parsed AS (
    SELECT *, AI_PARSE_DOCUMENT(
        TO_FILE('@DATA_STAGE', relative_path),
        {'mode': 'LAYOUT', 'page_split': false}
    ) AS contents
    FROM DIRECTORY(@DATA_STAGE)
    WHERE LOWER(relative_path) = 'faq_document.pdf'
)
SELECT * FROM parsed;

CREATE OR REPLACE TABLE raw_operation_manuals AS
WITH parsed AS (
    SELECT *, AI_PARSE_DOCUMENT(
        TO_FILE('@DATA_STAGE', relative_path),
        {'mode': 'LAYOUT', 'extract_images': true, 'page_split': false}
    ) AS contents
    FROM DIRECTORY(@DATA_STAGE)
    WHERE LOWER(relative_path) = 'operation_manual_w_images.pdf'
)
SELECT * FROM parsed;

-- -----------------------------------------------
-- Step 10. セットアップ確認
-- 各テーブルの件数が 0 の場合はファイルアップロードが未完了です。
-- -----------------------------------------------
SELECT 'dim_customers'    AS table_name, COUNT(*) AS row_count FROM dim_customers    UNION ALL
SELECT 'dim_products'     AS table_name, COUNT(*) AS row_count FROM dim_products     UNION ALL
SELECT 'fact_orders'      AS table_name, COUNT(*) AS row_count FROM fact_orders      UNION ALL
SELECT 'fact_payments'    AS table_name, COUNT(*) AS row_count FROM fact_payments    UNION ALL
SELECT 'fact_web_logs'    AS table_name, COUNT(*) AS row_count FROM fact_web_logs    UNION ALL
SELECT 'raw_sns_mentions' AS table_name, COUNT(*) AS row_count FROM raw_sns_mentions UNION ALL
SELECT 'raw_voice_logs'   AS table_name, COUNT(*) AS row_count FROM raw_voice_logs   UNION ALL
SELECT 'raw_ad_creatives' AS table_name, COUNT(*) AS row_count FROM raw_ad_creatives
ORDER BY table_name;
