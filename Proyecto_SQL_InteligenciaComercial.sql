/* ============================================================
   PROYECTO: Sistema de Inteligencia Comercial
   Empresa ficticia: Andina Distribuciones S.A.C.
   Motor: SQL Server (T-SQL) — ejecutar en SSMS
   Autor: Alonso Ponce — Practicante de Inteligencia Comercial
   ============================================================
   Este script se ejecuta en 5 bloques, EN ORDEN:
     BLOQUE 1: Creación de base de datos y tablas (modelo relacional)
     BLOQUE 2: Carga de datos maestros (regiones, categorías, productos, vendedores, clientes)
     BLOQUE 3: Generación de transacciones de venta (2 años, ~1500 registros)
     BLOQUE 4: Vista y procedimiento almacenado (automatización de reportes)
     BLOQUE 5: Consultas analíticas de Inteligencia Comercial (el corazón del proyecto)
   Ejecuta cada bloque completo (Ctrl+Shift+E o F5) antes de pasar al siguiente.
   ============================================================ */


/* ============================================================
   BLOQUE 1 — MODELO DE DATOS
   ============================================================ */

IF DB_ID('AndinaDistribucionesDB') IS NOT NULL
BEGIN
    ALTER DATABASE AndinaDistribucionesDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE AndinaDistribucionesDB;
END
GO

CREATE DATABASE AndinaDistribucionesDB;
GO

USE AndinaDistribucionesDB;
GO

CREATE TABLE Regiones (
    RegionID        INT IDENTITY(1,1) PRIMARY KEY,
    NombreRegion    VARCHAR(50) NOT NULL
);

CREATE TABLE Categorias (
    CategoriaID     INT IDENTITY(1,1) PRIMARY KEY,
    NombreCategoria VARCHAR(50) NOT NULL
);

CREATE TABLE Productos (
    ProductoID      INT IDENTITY(1,1) PRIMARY KEY,
    NombreProducto  VARCHAR(80) NOT NULL,
    CategoriaID     INT NOT NULL FOREIGN KEY REFERENCES Categorias(CategoriaID),
    PrecioUnitario  DECIMAL(10,2) NOT NULL,
    CostoUnitario   DECIMAL(10,2) NOT NULL
);

CREATE TABLE Vendedores (
    VendedorID      INT IDENTITY(1,1) PRIMARY KEY,
    NombreVendedor  VARCHAR(80) NOT NULL,
    RegionID        INT NOT NULL FOREIGN KEY REFERENCES Regiones(RegionID),
    FechaIngreso    DATE NOT NULL
);

CREATE TABLE Clientes (
    ClienteID       INT IDENTITY(1,1) PRIMARY KEY,
    NombreCliente   VARCHAR(100) NOT NULL,
    TipoCliente     VARCHAR(20) NOT NULL CHECK (TipoCliente IN ('Mayorista','Minorista')),
    RegionID        INT NOT NULL FOREIGN KEY REFERENCES Regiones(RegionID),
    FechaRegistro   DATE NOT NULL
);

CREATE TABLE Ventas (
    VentaID         INT IDENTITY(1,1) PRIMARY KEY,
    Fecha           DATE NOT NULL,
    ClienteID       INT NOT NULL FOREIGN KEY REFERENCES Clientes(ClienteID),
    VendedorID      INT NOT NULL FOREIGN KEY REFERENCES Vendedores(VendedorID),
    ProductoID      INT NOT NULL FOREIGN KEY REFERENCES Productos(ProductoID),
    Cantidad        INT NOT NULL,
    PrecioUnitario  DECIMAL(10,2) NOT NULL,
    Descuento       DECIMAL(4,3) NOT NULL DEFAULT 0  -- 0.000 a 0.150
);
GO


/* ============================================================
   BLOQUE 2 — DATOS MAESTROS
   ============================================================ */

INSERT INTO Regiones (NombreRegion) VALUES
('Lima'), ('Arequipa'), ('Trujillo'), ('Chiclayo'), ('Cusco'), ('Piura');

INSERT INTO Categorias (NombreCategoria) VALUES
('Abarrotes'), ('Bebidas'), ('Cuidado Personal'), ('Limpieza del Hogar'), ('Snacks'), ('Lácteos');

INSERT INTO Productos (NombreProducto, CategoriaID, PrecioUnitario, CostoUnitario) VALUES
('Arroz Extra 5kg', 1, 24.90, 18.50),
('Fideos Spaghetti 500g', 1, 3.80, 2.60),
('Aceite Vegetal 1L', 1, 9.50, 7.10),
('Gaseosa Cola 1.5L', 2, 6.90, 4.80),
('Agua Mineral 625ml', 2, 2.20, 1.30),
('Jugo de Frutas 1L', 2, 5.50, 3.70),
('Shampoo 400ml', 3, 14.90, 10.20),
('Jabón de Tocador x3', 3, 8.40, 5.60),
('Pasta Dental 90g', 3, 6.20, 4.10),
('Detergente 800g', 4, 11.90, 8.30),
('Lejía 1L', 4, 4.50, 2.90),
('Limpiador Multiusos 900ml', 4, 7.80, 5.20),
('Papas Fritas 150g', 5, 4.90, 3.10),
('Galletas Surtidas 300g', 5, 5.90, 3.80),
('Snack de Maíz 200g', 5, 3.50, 2.20),
('Leche Evaporada 400g', 6, 4.20, 2.90),
('Yogurt 1L', 6, 8.90, 6.10),
('Queso Fresco 500g', 6, 15.50, 11.20);

INSERT INTO Vendedores (NombreVendedor, RegionID, FechaIngreso) VALUES
('Carla Reyes', 1, '2022-03-01'),
('Jorge Salazar', 1, '2023-01-15'),
('María Quispe', 2, '2021-11-10'),
('Luis Fernández', 3, '2022-07-20'),
('Andrea Torres', 4, '2023-05-05'),
('Pedro Huamán', 5, '2021-09-12'),
('Diana Castillo', 6, '2022-10-30'),
('Renzo Alvarado', 1, '2024-02-01');

-- 40 clientes distribuidos en las 6 regiones (script compacto con generación numérica)
;WITH ClientesBase AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM ClientesBase WHERE n < 40
)
INSERT INTO Clientes (NombreCliente, TipoCliente, RegionID, FechaRegistro)
SELECT
    'Cliente ' + RIGHT('00' + CAST(n AS VARCHAR(2)), 2) +
        ' - ' + CASE (n % 6)
            WHEN 0 THEN 'Bodega'
            WHEN 1 THEN 'Minimarket'
            WHEN 2 THEN 'Distribuidora'
            WHEN 3 THEN 'Mayorista'
            WHEN 4 THEN 'Almacén'
            ELSE 'Comercial' END,
    CASE WHEN n % 3 = 0 THEN 'Mayorista' ELSE 'Minorista' END,
    ((n - 1) % 6) + 1,
    DATEADD(DAY, - (n * 11) % 700, '2025-12-31')
FROM ClientesBase
OPTION (MAXRECURSION 0);
GO


/* ============================================================
   BLOQUE 3 — TRANSACCIONES DE VENTA (2024-01-01 a 2025-12-31)
   Generación set-based (sin cursores/loops) usando una tabla numérica
   y valores pseudoaleatorios con CHECKSUM(NEWID()).
   ============================================================ */

;WITH Numeros AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM Numeros WHERE n < 1500
),
Staging AS (
    SELECT
        DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 730, '2024-01-01') AS Fecha,
        (ABS(CHECKSUM(NEWID())) % 40) + 1  AS ClienteID,
        (ABS(CHECKSUM(NEWID())) % 8)  + 1  AS VendedorID,
        (ABS(CHECKSUM(NEWID())) % 18) + 1  AS ProductoID,
        (ABS(CHECKSUM(NEWID())) % 15) + 1  AS Cantidad,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 25
             THEN CAST((ABS(CHECKSUM(NEWID())) % 15) AS DECIMAL(10,2)) / 100
             ELSE 0 END AS Descuento
    FROM Numeros
)
INSERT INTO Ventas (Fecha, ClienteID, VendedorID, ProductoID, Cantidad, PrecioUnitario, Descuento)
SELECT
    s.Fecha, s.ClienteID, s.VendedorID, s.ProductoID, s.Cantidad,
    p.PrecioUnitario, s.Descuento
FROM Staging s
JOIN Productos p ON p.ProductoID = s.ProductoID
OPTION (MAXRECURSION 0);
GO

-- Verificación rápida
SELECT COUNT(*) AS TotalVentas, MIN(Fecha) AS Desde, MAX(Fecha) AS Hasta FROM Ventas;
GO


/* ============================================================
   BLOQUE 4 — AUTOMATIZACIÓN: VISTA + PROCEDIMIENTO ALMACENADO
   (conecta con tu experiencia en automatización de reportes)
   ============================================================ */

-- Vista: base lista para tableros (Power BI / Excel) con ingreso y margen por línea
CREATE OR ALTER VIEW vw_VentasDetalle AS
SELECT
    v.VentaID,
    v.Fecha,
    YEAR(v.Fecha)  AS Anio,
    MONTH(v.Fecha) AS Mes,
    c.NombreCliente, c.TipoCliente, r.NombreRegion,
    ve.NombreVendedor,
    p.NombreProducto, cat.NombreCategoria,
    v.Cantidad,
    v.PrecioUnitario,
    v.Descuento,
    (v.Cantidad * v.PrecioUnitario * (1 - v.Descuento)) AS IngresoNeto,
    (v.Cantidad * p.CostoUnitario) AS CostoTotal,
    (v.Cantidad * v.PrecioUnitario * (1 - v.Descuento)) - (v.Cantidad * p.CostoUnitario) AS MargenBruto
FROM Ventas v
JOIN Clientes c    ON c.ClienteID = v.ClienteID
JOIN Regiones r    ON r.RegionID = c.RegionID
JOIN Vendedores ve ON ve.VendedorID = v.VendedorID
JOIN Productos p   ON p.ProductoID = v.ProductoID
JOIN Categorias cat ON cat.CategoriaID = p.CategoriaID;
GO

-- Procedimiento: reporte comercial parametrizado por rango de fechas y región (opcional)
CREATE OR ALTER PROCEDURE sp_ReporteComercial
    @FechaInicio DATE,
    @FechaFin    DATE,
    @RegionID    INT = NULL   -- NULL = todas las regiones
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        NombreRegion,
        NombreCategoria,
        COUNT(*)                AS NumeroTransacciones,
        SUM(Cantidad)           AS UnidadesVendidas,
        SUM(IngresoNeto)        AS IngresoTotal,
        SUM(MargenBruto)        AS MargenTotal,
        ROUND(SUM(MargenBruto) / NULLIF(SUM(IngresoNeto),0) * 100, 1) AS MargenPct
    FROM vw_VentasDetalle
    WHERE Fecha BETWEEN @FechaInicio AND @FechaFin
      AND (@RegionID IS NULL OR NombreRegion = (SELECT NombreRegion FROM Regiones WHERE RegionID = @RegionID))
    GROUP BY NombreRegion, NombreCategoria
    ORDER BY NombreRegion, IngresoTotal DESC;
END
GO

-- Ejemplo de uso:
-- EXEC sp_ReporteComercial @FechaInicio = '2025-01-01', @FechaFin = '2025-12-31';


/* ============================================================
   BLOQUE 5 — CONSULTAS DE INTELIGENCIA COMERCIAL
   Cada consulta responde una pregunta de negocio concreta.
   ============================================================ */

-- 5.1 Ingreso, margen y % de margen por región (visión ejecutiva)
SELECT
    NombreRegion,
    SUM(IngresoNeto) AS IngresoTotal,
    SUM(MargenBruto) AS MargenTotal,
    ROUND(SUM(MargenBruto) / NULLIF(SUM(IngresoNeto),0) * 100, 1) AS MargenPct
FROM vw_VentasDetalle
GROUP BY NombreRegion
ORDER BY IngresoTotal DESC;

-- 5.2 Top 10 productos por ingreso (Pareto de portafolio)
SELECT TOP 10
    NombreProducto, NombreCategoria,
    SUM(Cantidad) AS UnidadesVendidas,
    SUM(IngresoNeto) AS IngresoTotal
FROM vw_VentasDetalle
GROUP BY NombreProducto, NombreCategoria
ORDER BY IngresoTotal DESC;

-- 5.3 Ranking de vendedores por mes (función de ventana RANK)
SELECT Anio, Mes, NombreVendedor, IngresoMes, RankingMes
FROM (
    SELECT
        Anio, Mes, NombreVendedor,
        SUM(IngresoNeto) AS IngresoMes,
        RANK() OVER (PARTITION BY Anio, Mes ORDER BY SUM(IngresoNeto) DESC) AS RankingMes
    FROM vw_VentasDetalle
    GROUP BY Anio, Mes, NombreVendedor
) x
WHERE RankingMes <= 3
ORDER BY Anio, Mes, RankingMes;

-- 5.4 Evolución mensual de ingresos con variación % vs. mes anterior (LAG)
WITH VentasMensuales AS (
    SELECT Anio, Mes, SUM(IngresoNeto) AS IngresoMes
    FROM vw_VentasDetalle
    GROUP BY Anio, Mes
)
SELECT
    Anio, Mes, IngresoMes,
    LAG(IngresoMes) OVER (ORDER BY Anio, Mes) AS IngresoMesAnterior,
    ROUND(
        (IngresoMes - LAG(IngresoMes) OVER (ORDER BY Anio, Mes))
        / NULLIF(LAG(IngresoMes) OVER (ORDER BY Anio, Mes), 0) * 100, 1
    ) AS VariacionPct
FROM VentasMensuales
ORDER BY Anio, Mes;

-- 5.5 Segmentación RFM de clientes (Recencia, Frecuencia, Monto) con NTILE
WITH RFM_Base AS (
    SELECT
        c.ClienteID, c.NombreCliente, c.TipoCliente,
        DATEDIFF(DAY, MAX(v.Fecha), '2025-12-31') AS Recencia,
        COUNT(*) AS Frecuencia,
        SUM(v.Cantidad * v.PrecioUnitario * (1 - v.Descuento)) AS Monto
    FROM Ventas v
    JOIN Clientes c ON c.ClienteID = v.ClienteID
    GROUP BY c.ClienteID, c.NombreCliente, c.TipoCliente
),
RFM_Score AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY Recencia DESC)  AS R_Score,  -- 4 = más reciente
        NTILE(4) OVER (ORDER BY Frecuencia ASC)  AS F_Score,  -- 4 = más frecuente
        NTILE(4) OVER (ORDER BY Monto ASC)       AS M_Score   -- 4 = mayor monto
    FROM RFM_Base
)
SELECT
    NombreCliente, TipoCliente, Recencia, Frecuencia, Monto,
    R_Score, F_Score, M_Score,
    (R_Score + F_Score + M_Score) AS RFM_Total,
    CASE
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Cliente Top'
        WHEN R_Score <= 2 AND F_Score <= 2 THEN 'En riesgo / inactivo'
        ELSE 'Cliente regular'
    END AS Segmento
FROM RFM_Score
ORDER BY RFM_Total DESC;

-- 5.6 Clientes sin compras en los últimos 90 días (alerta de posible churn)
SELECT
    c.NombreCliente, c.TipoCliente, r.NombreRegion,
    MAX(v.Fecha) AS UltimaCompra,
    DATEDIFF(DAY, MAX(v.Fecha), '2025-12-31') AS DiasSinComprar
FROM Clientes c
JOIN Regiones r ON r.RegionID = c.RegionID
LEFT JOIN Ventas v ON v.ClienteID = c.ClienteID
GROUP BY c.NombreCliente, c.TipoCliente, r.NombreRegion
HAVING DATEDIFF(DAY, MAX(v.Fecha), '2025-12-31') > 90
    OR MAX(v.Fecha) IS NULL
ORDER BY DiasSinComprar DESC;

-- 5.7 Ticket promedio por tipo de cliente (Mayorista vs. Minorista)
SELECT
    TipoCliente,
    COUNT(DISTINCT VentaID) AS NumeroCompras,
    ROUND(AVG(IngresoNeto), 2) AS TicketPromedio
FROM vw_VentasDetalle
GROUP BY TipoCliente;

-- 5.8 Productos frecuentemente comprados por los mismos clientes (afinidad básica de canasta)
SELECT
    p1.NombreProducto AS ProductoA,
    p2.NombreProducto AS ProductoB,
    COUNT(DISTINCT v1.ClienteID) AS ClientesEnComun
FROM Ventas v1
JOIN Ventas v2 ON v1.ClienteID = v2.ClienteID AND v1.ProductoID < v2.ProductoID
JOIN Productos p1 ON p1.ProductoID = v1.ProductoID
JOIN Productos p2 ON p2.ProductoID = v2.ProductoID
GROUP BY p1.NombreProducto, p2.NombreProducto
HAVING COUNT(DISTINCT v1.ClienteID) >= 8
ORDER BY ClientesEnComun DESC;

/* ============================================================
   BLOQUE 6 (opcional) — ÍNDICES PARA OPTIMIZACIÓN
   Útil para hablar de rendimiento en la entrevista.
   ============================================================ */
CREATE INDEX IX_Ventas_Fecha ON Ventas(Fecha);
CREATE INDEX IX_Ventas_ClienteID ON Ventas(ClienteID);
GO
