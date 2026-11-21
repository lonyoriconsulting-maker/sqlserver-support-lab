/* =====================================================================
   01_create_telematicslab.sql
   Port of the telematics-safety-engine schema (Django/SQLite) to SQL Server 2022.
   Lab only. Fictional data only. Safe to re-run: it drops and recreates TelematicsLab.

   Porting notes (SQLite -> SQL Server):
   - integer AUTOINCREMENT        -> INT IDENTITY(1,1)
   - decimal (no precision)       -> DECIMAL(p,s) chosen per column
   - datetime                     -> DATETIME2(0)
   - varchar                      -> NVARCHAR (Unicode, safe for Swahili names)
   - text                         -> NVARCHAR(MAX)
   - column "timestamp"           -> renamed recorded_at ("timestamp" is a SQL Server type keyword)
   - DEFERRABLE INITIALLY DEFERRED -> not supported; FKs are checked immediately
   ===================================================================== */

SET NOCOUNT ON;
GO

USE master;
GO

IF DB_ID(N'TelematicsLab') IS NOT NULL
BEGIN
    ALTER DATABASE TelematicsLab SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TelematicsLab;
END
GO

CREATE DATABASE TelematicsLab;
GO

USE TelematicsLab;
GO

/* ---------- Tables ---------- */

CREATE TABLE dbo.Driver (
    id             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Driver PRIMARY KEY,
    full_name      NVARCHAR(150) NOT NULL,
    license_number NVARCHAR(50)  NOT NULL CONSTRAINT UQ_Driver_license UNIQUE,
    phone_number   NVARCHAR(20)  NOT NULL,
    created_at     DATETIME2(0)  NOT NULL CONSTRAINT DF_Driver_created DEFAULT (SYSUTCDATETIME())
);
GO

CREATE TABLE dbo.Vehicle (
    id                        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Vehicle PRIMARY KEY,
    plate_number              NVARCHAR(20)  NOT NULL CONSTRAINT UQ_Vehicle_plate UNIQUE,
    make_model                NVARCHAR(100) NOT NULL,
    fuel_tank_capacity_liters DECIMAL(8,2)  NOT NULL CONSTRAINT CK_Vehicle_tank CHECK (fuel_tank_capacity_liters > 0),
    created_at                DATETIME2(0)  NOT NULL CONSTRAINT DF_Vehicle_created DEFAULT (SYSUTCDATETIME())
);
GO

CREATE TABLE dbo.TripLog (
    id                INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TripLog PRIMARY KEY,
    driver_id         INT           NOT NULL CONSTRAINT FK_TripLog_Driver  FOREIGN KEY REFERENCES dbo.Driver(id),
    vehicle_id        INT           NOT NULL CONSTRAINT FK_TripLog_Vehicle FOREIGN KEY REFERENCES dbo.Vehicle(id),
    start_time        DATETIME2(0)  NOT NULL,
    end_time          DATETIME2(0)  NULL,
    start_odometer_km DECIMAL(10,2) NOT NULL,
    end_odometer_km   DECIMAL(10,2) NULL,
    CONSTRAINT CK_TripLog_times    CHECK (end_time IS NULL OR end_time >= start_time),
    CONSTRAINT CK_TripLog_odometer CHECK (end_odometer_km IS NULL OR end_odometer_km >= start_odometer_km)
);
GO

CREATE TABLE dbo.TelemetryReading (
    id                INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TelemetryReading PRIMARY KEY,
    trip_id           INT           NOT NULL CONSTRAINT FK_Reading_Trip FOREIGN KEY REFERENCES dbo.TripLog(id),
    recorded_at       DATETIME2(0)  NOT NULL,
    speed_kmh         DECIMAL(6,2)  NOT NULL CONSTRAINT CK_Reading_speed CHECK (speed_kmh >= 0),
    fuel_level_liters DECIMAL(8,2)  NOT NULL CONSTRAINT CK_Reading_fuel  CHECK (fuel_level_liters >= 0),
    latitude          DECIMAL(9,6)  NULL,
    longitude         DECIMAL(9,6)  NULL
);
GO

CREATE TABLE dbo.Violation (
    id             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Violation PRIMARY KEY,
    trip_id        INT           NOT NULL CONSTRAINT FK_Violation_Trip    FOREIGN KEY REFERENCES dbo.TripLog(id),
    reading_id     INT           NULL     CONSTRAINT FK_Violation_Reading FOREIGN KEY REFERENCES dbo.TelemetryReading(id),
    violation_type NVARCHAR(20)  NOT NULL,
    detected_at    DATETIME2(0)  NOT NULL,
    detail         NVARCHAR(MAX) NOT NULL
);
GO

/* ---------- Indexes on foreign keys and common lookups ---------- */

CREATE INDEX IX_TripLog_driver_id   ON dbo.TripLog (driver_id);
CREATE INDEX IX_TripLog_vehicle_id  ON dbo.TripLog (vehicle_id);
CREATE INDEX IX_Reading_trip_time   ON dbo.TelemetryReading (trip_id, recorded_at);
CREATE INDEX IX_Violation_trip_id   ON dbo.Violation (trip_id);
CREATE INDEX IX_Violation_type_time ON dbo.Violation (violation_type, detected_at);
GO

/* ---------- Fictional sample data (not real people, plates or vehicles) ---------- */

INSERT dbo.Driver (full_name, license_number, phone_number) VALUES
 (N'Test Driver One',   N'LIC-0001', N'+255700000001'),
 (N'Test Driver Two',   N'LIC-0002', N'+255700000002'),
 (N'Test Driver Three', N'LIC-0003', N'+255700000003');

INSERT dbo.Vehicle (plate_number, make_model, fuel_tank_capacity_liters) VALUES
 (N'T000AAA', N'Sample Truck A', 120.00),
 (N'T000BBB', N'Sample Truck B',  90.00),
 (N'T000CCC', N'Sample Van C',    60.00);

INSERT dbo.TripLog (driver_id, vehicle_id, start_time, end_time, start_odometer_km, end_odometer_km) VALUES
 (1, 1, '2026-11-10 06:00:00', '2026-11-10 09:00:00', 10000.00, 10180.00),
 (2, 2, '2026-11-10 07:00:00', '2026-11-10 08:30:00', 25000.00, 25000.00),
 (3, 3, '2026-11-11 05:30:00', '2026-11-11 07:30:00',  8000.00,  8110.00);

/* Trip 1: normal driving with one overspeed reading */
INSERT dbo.TelemetryReading (trip_id, recorded_at, speed_kmh, fuel_level_liters, latitude, longitude) VALUES
 (1, '2026-11-10 06:00:00',  0.00, 100.00, -3.386700, 36.682900),
 (1, '2026-11-10 06:30:00', 72.00,  96.50, -3.400000, 36.700000),
 (1, '2026-11-10 07:00:00', 118.00, 92.00, -3.450000, 36.750000),
 (1, '2026-11-10 08:00:00', 80.00,  85.00, -3.500000, 36.800000),
 (1, '2026-11-10 09:00:00',  0.00,  80.00, -3.550000, 36.850000);

/* Trip 2: vehicle stationary while fuel drops sharply (siphoning pattern) */
INSERT dbo.TelemetryReading (trip_id, recorded_at, speed_kmh, fuel_level_liters, latitude, longitude) VALUES
 (2, '2026-11-10 07:00:00', 0.00, 70.00, -3.370000, 36.690000),
 (2, '2026-11-10 07:30:00', 0.00, 69.80, -3.370000, 36.690000),
 (2, '2026-11-10 08:00:00', 0.00, 48.00, -3.370000, 36.690000),
 (2, '2026-11-10 08:30:00', 0.00, 47.90, -3.370000, 36.690000);

/* Trip 3: normal driving */
INSERT dbo.TelemetryReading (trip_id, recorded_at, speed_kmh, fuel_level_liters, latitude, longitude) VALUES
 (3, '2026-11-11 05:30:00',  0.00, 55.00, -3.360000, 36.670000),
 (3, '2026-11-11 06:30:00', 65.00, 50.00, -3.410000, 36.720000),
 (3, '2026-11-11 07:30:00',  0.00, 45.50, -3.460000, 36.770000);

INSERT dbo.Violation (trip_id, reading_id, violation_type, detected_at, detail) VALUES
 (1, 3, N'OVERSPEED',   '2026-11-10 07:00:00', N'Speed 118 km/h exceeds the 100 km/h limit.'),
 (2, 8, N'FUEL_SIPHON', '2026-11-10 08:00:00', N'Fuel fell 21.80 L in 30 minutes while the vehicle was stationary.');
GO

/* ---------- Verification (one result set per check) ---------- */

SELECT 'Driver' AS table_name, COUNT(*) AS row_count FROM dbo.Driver
UNION ALL SELECT 'Vehicle',          COUNT(*) FROM dbo.Vehicle
UNION ALL SELECT 'TripLog',          COUNT(*) FROM dbo.TripLog
UNION ALL SELECT 'TelemetryReading', COUNT(*) FROM dbo.TelemetryReading
UNION ALL SELECT 'Violation',        COUNT(*) FROM dbo.Violation;
GO

SELECT fk.name AS foreign_key,
       OBJECT_NAME(fk.parent_object_id)     AS child_table,
       OBJECT_NAME(fk.referenced_object_id) AS parent_table
FROM sys.foreign_keys AS fk
ORDER BY child_table, foreign_key;
GO

SELECT 'SCRIPT_OK' AS status, DB_NAME() AS database_name;
GO
