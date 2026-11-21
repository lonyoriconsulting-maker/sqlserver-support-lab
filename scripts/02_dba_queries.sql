/* =====================================================================
   02_dba_queries.sql
   Ten DBA / support queries against TelematicsLab (SQL Server 2022).
   Read-only: nothing here changes data. Run after 01_create_telematicslab.sql.
   Each query says what a support specialist uses it for.
   ===================================================================== */

SET NOCOUNT ON;
GO
USE TelematicsLab;
GO

/* 1. Instance health: version, edition, and state of every database.
      Use: first check when a user says "the system is slow or down". */
SELECT SERVERPROPERTY('ProductVersion') AS product_version,
       SERVERPROPERTY('Edition')        AS edition;

SELECT name, state_desc, recovery_model_desc, compatibility_level
FROM sys.databases
ORDER BY name;
GO

/* 2. Data and log file sizes and locations for this database.
      Use: capacity checks and finding where files live before a restore. */
SELECT name AS logical_name,
       type_desc,
       physical_name,
       CAST(size * 8 / 1024.0 AS DECIMAL(10,2)) AS size_mb
FROM sys.database_files;
GO

/* 3. Row count per table.
      Use: quick sanity check after a restore or a deployment. */
SELECT t.name AS table_name, SUM(ps.row_count) AS row_count
FROM sys.dm_db_partition_stats AS ps
JOIN sys.tables AS t ON t.object_id = ps.object_id
WHERE ps.index_id IN (0, 1)
GROUP BY t.name
ORDER BY t.name;
GO

/* 4. Last full backup per database (NULL = never backed up).
      Use: backup audit. TelematicsLab should show NULL until a backup is taken. */
SELECT d.name AS database_name,
       MAX(b.backup_finish_date) AS last_full_backup
FROM sys.databases AS d
LEFT JOIN msdb.dbo.backupset AS b
       ON b.database_name = d.name AND b.type = 'D'
GROUP BY d.name
ORDER BY d.name;
GO

/* 5. Session summary (counts only, no user or host names).
      Use: see how many connections exist and whether any are blocked. */
SELECT status, COUNT(*) AS sessions
FROM sys.dm_exec_sessions
WHERE is_user_process = 1
GROUP BY status;

SELECT COUNT(*) AS blocked_requests
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;
GO

/* 6. Fuel-siphoning pattern: fuel drops more than 10 L between two
      consecutive readings while the vehicle is stationary.
      Use: the business rule behind the Violation table, expressed in SQL. */
SELECT v.plate_number,
       x.trip_id,
       x.recorded_at,
       x.prev_fuel,
       x.fuel_level_liters,
       x.prev_fuel - x.fuel_level_liters AS fuel_drop_liters
FROM (
    SELECT r.trip_id, r.recorded_at, r.speed_kmh, r.fuel_level_liters,
           LAG(r.fuel_level_liters) OVER (PARTITION BY r.trip_id ORDER BY r.recorded_at) AS prev_fuel,
           LAG(r.speed_kmh)         OVER (PARTITION BY r.trip_id ORDER BY r.recorded_at) AS prev_speed
    FROM dbo.TelemetryReading AS r
) AS x
JOIN dbo.TripLog AS t ON t.id = x.trip_id
JOIN dbo.Vehicle AS v ON v.id = t.vehicle_id
WHERE x.speed_kmh = 0
  AND x.prev_speed = 0
  AND x.prev_fuel - x.fuel_level_liters > 10;
GO

/* 7. Overspeed readings above 100 km/h with driver and vehicle.
      Use: answering "who was driving, and in what vehicle?" for an incident. */
SELECT d.full_name, v.plate_number, r.recorded_at, r.speed_kmh
FROM dbo.TelemetryReading AS r
JOIN dbo.TripLog AS t ON t.id = r.trip_id
JOIN dbo.Driver  AS d ON d.id = t.driver_id
JOIN dbo.Vehicle AS v ON v.id = t.vehicle_id
WHERE r.speed_kmh > 100
ORDER BY r.speed_kmh DESC;
GO

/* 8. Trip summary: duration and distance per trip.
      Use: report requests from operations managers. */
SELECT t.id AS trip_id,
       d.full_name,
       v.plate_number,
       DATEDIFF(MINUTE, t.start_time, t.end_time) AS duration_minutes,
       t.end_odometer_km - t.start_odometer_km    AS distance_km
FROM dbo.TripLog AS t
JOIN dbo.Driver  AS d ON d.id = t.driver_id
JOIN dbo.Vehicle AS v ON v.id = t.vehicle_id
ORDER BY t.id;
GO

/* 9. Violations per driver, worst first.
      Use: a simple access-review style report for managers. */
SELECT d.full_name,
       COUNT(vi.id) AS violations
FROM dbo.Driver AS d
LEFT JOIN dbo.TripLog   AS t  ON t.driver_id = d.id
LEFT JOIN dbo.Violation AS vi ON vi.trip_id  = t.id
GROUP BY d.full_name
ORDER BY violations DESC, d.full_name;
GO

/* 10. Index inventory for this database.
       Use: troubleshooting slow queries and confirming foreign keys are indexed. */
SELECT OBJECT_NAME(i.object_id) AS table_name,
       i.name                   AS index_name,
       i.type_desc,
       i.is_unique,
       i.is_primary_key
FROM sys.indexes AS i
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
  AND i.name IS NOT NULL
ORDER BY table_name, index_name;
GO
