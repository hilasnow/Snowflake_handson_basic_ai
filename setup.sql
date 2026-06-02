-- =============================================================
-- setup.sql  –  JBS ハンズオン 事前セットアップ
--
-- 対象ノートブック : part1_snowflake_basics.ipynb (NB1)
-- ベース素材       : Zero to Snowflake vignette 用 setup.sql
-- 削除したもの     : tb_dev_wh / tb_analyst_wh, tb_dev / tb_analyst ロール,
--                    governance スキーマ, 不要ビュー, Cortex AI 関連
-- =============================================================

USE ROLE sysadmin;

-- -----------------------------------------------
-- 1. データベース・スキーマ
-- -----------------------------------------------
CREATE OR REPLACE DATABASE tb_101;
CREATE OR REPLACE SCHEMA tb_101.raw_pos;
CREATE OR REPLACE SCHEMA tb_101.raw_customer;
CREATE OR REPLACE SCHEMA tb_101.harmonized;
CREATE OR REPLACE SCHEMA tb_101.analytics;

-- -----------------------------------------------
-- 2. ウェアハウス
-- -----------------------------------------------
CREATE OR REPLACE WAREHOUSE tb_de_wh
    WAREHOUSE_SIZE  = 'large'   -- 初期ロード用。スクリプト末尾でスケールダウン
    WAREHOUSE_TYPE  = 'standard'
    AUTO_SUSPEND    = 60
    AUTO_RESUME     = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Tasty Bytes データエンジニアリング用ウェアハウス';

-- -----------------------------------------------
-- 3. ロール・権限
-- -----------------------------------------------
USE ROLE securityadmin;

CREATE ROLE IF NOT EXISTS tb_admin          COMMENT = 'Tasty Bytes 管理者';
CREATE ROLE IF NOT EXISTS tb_data_engineer  COMMENT = 'Tasty Bytes データエンジニア';

-- ロール階層
GRANT ROLE tb_admin         TO ROLE sysadmin;
GRANT ROLE tb_data_engineer TO ROLE tb_admin;

-- アカウントレベル権限
USE ROLE accountadmin;
GRANT IMPORTED PRIVILEGES ON DATABASE snowflake TO ROLE tb_data_engineer;

-- DB・スキーマ権限
USE ROLE securityadmin;
GRANT USAGE ON DATABASE tb_101 TO ROLE tb_admin;
GRANT USAGE ON DATABASE tb_101 TO ROLE tb_data_engineer;
GRANT USAGE ON ALL SCHEMAS IN DATABASE tb_101 TO ROLE tb_admin;
GRANT USAGE ON ALL SCHEMAS IN DATABASE tb_101 TO ROLE tb_data_engineer;
GRANT ALL ON SCHEMA tb_101.raw_pos      TO ROLE tb_admin;
GRANT ALL ON SCHEMA tb_101.raw_pos      TO ROLE tb_data_engineer;
GRANT ALL ON SCHEMA tb_101.raw_customer TO ROLE tb_admin;
GRANT ALL ON SCHEMA tb_101.raw_customer TO ROLE tb_data_engineer;
GRANT ALL ON SCHEMA tb_101.harmonized   TO ROLE tb_admin;
GRANT ALL ON SCHEMA tb_101.harmonized   TO ROLE tb_data_engineer;
GRANT ALL ON SCHEMA tb_101.analytics    TO ROLE tb_admin;
GRANT ALL ON SCHEMA tb_101.analytics    TO ROLE tb_data_engineer;

-- ウェアハウス権限
GRANT OWNERSHIP ON WAREHOUSE tb_de_wh TO ROLE tb_admin COPY CURRENT GRANTS;
GRANT ALL ON WAREHOUSE tb_de_wh TO ROLE tb_admin;
GRANT ALL ON WAREHOUSE tb_de_wh TO ROLE tb_data_engineer;

-- 将来テーブル・ビュー権限
GRANT ALL ON FUTURE TABLES IN SCHEMA tb_101.raw_pos      TO ROLE tb_admin;
GRANT ALL ON FUTURE TABLES IN SCHEMA tb_101.raw_pos      TO ROLE tb_data_engineer;
GRANT ALL ON FUTURE TABLES IN SCHEMA tb_101.raw_customer TO ROLE tb_admin;
GRANT ALL ON FUTURE TABLES IN SCHEMA tb_101.raw_customer TO ROLE tb_data_engineer;
GRANT ALL ON FUTURE VIEWS  IN SCHEMA tb_101.harmonized   TO ROLE tb_admin;
GRANT ALL ON FUTURE VIEWS  IN SCHEMA tb_101.harmonized   TO ROLE tb_data_engineer;
GRANT ALL ON FUTURE VIEWS  IN SCHEMA tb_101.analytics    TO ROLE tb_admin;
GRANT ALL ON FUTURE VIEWS  IN SCHEMA tb_101.analytics    TO ROLE tb_data_engineer;

-- -----------------------------------------------
-- 4. ファイルフォーマット・ステージ
-- -----------------------------------------------
USE ROLE sysadmin;
USE WAREHOUSE tb_de_wh;

CREATE OR REPLACE FILE FORMAT tb_101.public.csv_ff
    TYPE = 'csv';

CREATE OR REPLACE STAGE tb_101.public.s3load
    COMMENT      = 'クイックスタート S3 ステージ'
    URL          = 's3://sfquickstarts/frostbyte_tastybytes/'
    FILE_FORMAT  = tb_101.public.csv_ff;

-- -----------------------------------------------
-- 5. テーブル作成
-- -----------------------------------------------
CREATE OR REPLACE TABLE tb_101.raw_pos.country (
    country_id      NUMBER(18,0),
    country         VARCHAR,
    iso_currency    VARCHAR(3),
    iso_country     VARCHAR(2),
    city_id         NUMBER(19,0),
    city            VARCHAR,
    city_population VARCHAR
);

CREATE OR REPLACE TABLE tb_101.raw_pos.franchise (
    franchise_id NUMBER(38,0),
    first_name   VARCHAR,
    last_name    VARCHAR,
    city         VARCHAR,
    country      VARCHAR,
    e_mail       VARCHAR,
    phone_number VARCHAR
);

CREATE OR REPLACE TABLE tb_101.raw_pos.location (
    location_id      NUMBER(19,0),
    placekey         VARCHAR,
    location         VARCHAR,
    city             VARCHAR,
    region           VARCHAR,
    iso_country_code VARCHAR,
    country          VARCHAR
);

CREATE OR REPLACE TABLE tb_101.raw_pos.menu (
    menu_id                      NUMBER(19,0),
    menu_type_id                 NUMBER(38,0),
    menu_type                    VARCHAR,
    truck_brand_name             VARCHAR,
    menu_item_id                 NUMBER(38,0),
    menu_item_name               VARCHAR,
    item_category                VARCHAR,
    item_subcategory             VARCHAR,
    cost_of_goods_usd            NUMBER(38,4),
    sale_price_usd               NUMBER(38,4),
    menu_item_health_metrics_obj VARIANT
);

CREATE OR REPLACE TABLE tb_101.raw_pos.truck (
    truck_id            NUMBER(38,0),
    menu_type_id        NUMBER(38,0),
    primary_city        VARCHAR,
    region              VARCHAR,
    iso_region          VARCHAR,
    country             VARCHAR,
    iso_country_code    VARCHAR,
    franchise_flag      NUMBER(38,0),
    year                NUMBER(38,0),
    make                VARCHAR,
    model               VARCHAR,
    ev_flag             NUMBER(38,0),
    franchise_id        NUMBER(38,0),
    truck_opening_date  DATE
);

CREATE OR REPLACE TABLE tb_101.raw_pos.order_header (
    order_id                NUMBER(38,0),
    truck_id                NUMBER(38,0),
    location_id             FLOAT,
    customer_id             NUMBER(38,0),
    discount_id             VARCHAR,
    shift_id                NUMBER(38,0),
    shift_start_time        TIME(9),
    shift_end_time          TIME(9),
    order_channel           VARCHAR,
    order_ts                TIMESTAMP_NTZ(9),
    served_ts               VARCHAR,
    order_currency          VARCHAR(3),
    order_amount            NUMBER(38,4),
    order_tax_amount        VARCHAR,
    order_discount_amount   VARCHAR,
    order_total             NUMBER(38,4)
);

CREATE OR REPLACE TABLE tb_101.raw_pos.order_detail (
    order_detail_id             NUMBER(38,0),
    order_id                    NUMBER(38,0),
    menu_item_id                NUMBER(38,0),
    discount_id                 VARCHAR,
    line_number                 NUMBER(38,0),
    quantity                    NUMBER(5,0),
    unit_price                  NUMBER(38,4),
    price                       NUMBER(38,4),
    order_item_discount_amount  VARCHAR
);

CREATE OR REPLACE TABLE tb_101.raw_customer.customer_loyalty (
    customer_id         NUMBER(38,0),
    first_name          VARCHAR,
    last_name           VARCHAR,
    city                VARCHAR,
    country             VARCHAR,
    postal_code         VARCHAR,
    preferred_language  VARCHAR,
    gender              VARCHAR,
    favourite_brand     VARCHAR,
    marital_status      VARCHAR,
    children_count      VARCHAR,
    sign_up_date        DATE,
    birthday_date       DATE,
    e_mail              VARCHAR,
    phone_number        VARCHAR
);

-- -----------------------------------------------
-- 6. データロード
-- -----------------------------------------------
COPY INTO tb_101.raw_pos.country       FROM @tb_101.public.s3load/raw_pos/country/;
COPY INTO tb_101.raw_pos.franchise     FROM @tb_101.public.s3load/raw_pos/franchise/;
COPY INTO tb_101.raw_pos.location      FROM @tb_101.public.s3load/raw_pos/location/;
COPY INTO tb_101.raw_pos.menu          FROM @tb_101.public.s3load/raw_pos/menu/;
COPY INTO tb_101.raw_pos.truck         FROM @tb_101.public.s3load/raw_pos/truck/;
COPY INTO tb_101.raw_customer.customer_loyalty FROM @tb_101.public.s3load/raw_customer/customer_loyalty/;
COPY INTO tb_101.raw_pos.order_header  FROM @tb_101.public.s3load/raw_pos/order_header/;
COPY INTO tb_101.raw_pos.order_detail  FROM @tb_101.public.s3load/raw_pos/order_detail/;

-- -----------------------------------------------
-- 7. ビュー作成
-- -----------------------------------------------
CREATE OR REPLACE VIEW tb_101.harmonized.orders_v AS
SELECT
    oh.order_id, oh.truck_id, oh.order_ts,
    od.order_detail_id, od.line_number,
    m.truck_brand_name, m.menu_type,
    t.primary_city, t.region, t.country, t.franchise_flag, t.franchise_id,
    f.first_name AS franchisee_first_name, f.last_name AS franchisee_last_name,
    l.location_id,
    cl.customer_id, cl.first_name, cl.last_name, cl.e_mail, cl.phone_number,
    cl.children_count, cl.gender, cl.marital_status,
    od.menu_item_id, m.menu_item_name,
    od.quantity, od.unit_price, od.price,
    oh.order_amount, oh.order_tax_amount, oh.order_discount_amount, oh.order_total
FROM tb_101.raw_pos.order_detail od
JOIN tb_101.raw_pos.order_header  oh ON od.order_id      = oh.order_id
JOIN tb_101.raw_pos.truck          t ON oh.truck_id      = t.truck_id
JOIN tb_101.raw_pos.menu           m ON od.menu_item_id  = m.menu_item_id
JOIN tb_101.raw_pos.franchise      f ON t.franchise_id   = f.franchise_id
JOIN tb_101.raw_pos.location       l ON oh.location_id   = l.location_id
LEFT JOIN tb_101.raw_customer.customer_loyalty cl ON oh.customer_id = cl.customer_id;

CREATE OR REPLACE VIEW tb_101.analytics.orders_v
    COMMENT = 'Tasty Bytes 注文詳細ビュー'
AS
SELECT DATE(o.order_ts) AS date, * FROM tb_101.harmonized.orders_v o;

-- -----------------------------------------------
-- 8. truck_details テーブル作成（NB1 で使用）
-- -----------------------------------------------
-- truck_build カラム（VARIANT）を追加
ALTER TABLE tb_101.raw_pos.truck ADD COLUMN truck_build OBJECT;

-- year・make・model を OBJECT にまとめて格納
UPDATE tb_101.raw_pos.truck
SET truck_build = OBJECT_CONSTRUCT('year', year, 'make', make, 'model', model);

-- make データを一部意図的に破損させる（NB1 のデータ品質修正演習用）
UPDATE tb_101.raw_pos.truck
SET truck_build = OBJECT_INSERT(truck_build, 'make', 'Ford', TRUE)
WHERE truck_build:make::STRING = 'Ford_' AND truck_id % 2 = 0;

-- truck_details テーブル（year・make・model 列を除外した VARIANT 版）
CREATE OR REPLACE TABLE tb_101.raw_pos.truck_details
AS SELECT * EXCLUDE (year, make, model) FROM tb_101.raw_pos.truck;

-- -----------------------------------------------
-- 9. ウェアハウスをスケールダウン
-- -----------------------------------------------
ALTER WAREHOUSE tb_de_wh SET WAREHOUSE_SIZE = 'XSmall';


-- =============================================================
-- Part 2 : GlacierStyle セットアップ (NB2 / part2_cortex_ai 用)
--
-- ベース素材: cortex-handson-jp-4h_partner / part1_data_ingest.ipynb
-- データ  : data/ フォルダ内の CSV / JSON / PDF / 音声ファイル
--           → このリポジトリの data/ に同梱
-- =============================================================

-- -----------------------------------------------
-- G-1. 環境設定
-- -----------------------------------------------
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE WAREHOUSE IF NOT EXISTS GLACIERSTYLE_WH
    WAREHOUSE_SIZE      = 'large'
    WAREHOUSE_TYPE      = 'standard'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE GLACIERSTYLE_WH;

-- -----------------------------------------------
-- G-2. データベース・スキーマ
-- -----------------------------------------------
CREATE OR REPLACE DATABASE GLACIERSTYLE_DB;
CREATE OR REPLACE SCHEMA GLACIERSTYLE_DB.EC_ANALYTICS_SCHEMA;
USE SCHEMA GLACIERSTYLE_DB.EC_ANALYTICS_SCHEMA;

-- -----------------------------------------------
-- G-3. ステージ作成
-- -----------------------------------------------
CREATE OR REPLACE STAGE DATA_STAGE
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY  = (ENABLE = TRUE);

-- -----------------------------------------------
-- G-4. データファイルのアップロード（手動）
--
-- 事前にリポジトリの data/ フォルダを手元にダウンロードしておく。
-- https://github.com/hilasnow/Snowflake_handson_basic_ai
--
-- Snowsight での手順:
--   1. 左メニュー > Data > Databases > GLACIERSTYLE_DB
--      > EC_ANALYTICS_SCHEMA > Stages > DATA_STAGE を開く
--   2. 右上の「+ Files」ボタンから data/ 内の全ファイルを選択してアップロード
--      （CSV / JSON / PDF / voice_logs/*.mp3 をすべてアップロード）
--   3. アップロード完了後、以下を実行してディレクトリを更新
-- -----------------------------------------------
ALTER STAGE DATA_STAGE REFRESH;

-- -----------------------------------------------
-- G-5. ファイルフォーマット作成
-- -----------------------------------------------
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE                    = 'CSV'
    SKIP_HEADER             = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"';

CREATE OR REPLACE FILE FORMAT json_format
    TYPE             = 'JSON'
    STRIP_OUTER_ARRAY = TRUE;

-- -----------------------------------------------
-- G-6. テーブル作成
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
    post_id           VARCHAR PRIMARY KEY,
    platform          VARCHAR,
    post_type         VARCHAR,
    username          VARCHAR,
    display_name      VARCHAR,
    content           VARCHAR,
    posted_at         TIMESTAMP,
    likes             INTEGER,
    retweets          INTEGER,
    replies           INTEGER,
    hashtags          ARRAY,
    mentioned_products ARRAY,
    media_urls        ARRAY
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
-- G-7. データロード（CSV / JSON）
-- -----------------------------------------------
COPY INTO dim_customers   FROM @DATA_STAGE/customers.csv   FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO dim_products    FROM @DATA_STAGE/products.csv    FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO fact_orders     FROM @DATA_STAGE/orders.csv      FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO fact_payments   FROM @DATA_STAGE/payments.csv    FILE_FORMAT = (FORMAT_NAME = csv_format);
COPY INTO raw_ad_creatives FROM @DATA_STAGE/ad_creatives.csv FILE_FORMAT = (FORMAT_NAME = csv_format);

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
-- G-8. AI_TRANSCRIBE（音声→テキスト）
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
-- G-9. AI_PARSE_DOCUMENT（PDF→構造化）
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
-- G-10. ウェアハウスをスケールダウン
-- -----------------------------------------------
ALTER WAREHOUSE GLACIERSTYLE_WH SET WAREHOUSE_SIZE = 'XSmall';
