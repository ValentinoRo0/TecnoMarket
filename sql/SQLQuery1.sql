CREATE DATABASE GestionTecnoMarket;
GO
USE GestionTecnoMarket;
GO


---------- TABLAS ----------
-- Dimensión: Catálogo de Productos Tecnológicos
CREATE TABLE D_PRODUCTOS (
    IdProducto INT IDENTITY(1,1) PRIMARY KEY,
    SKU VARCHAR(50) NOT NULL UNIQUE,
    NombreProducto VARCHAR(100) NOT NULL,
    Categoria VARCHAR(50) NOT NULL,
    Marca VARCHAR(50) NOT NULL
);

-- Dimensión: Clientes Corporativos y Consumidores
CREATE TABLE D_CLIENTES (
    IdCliente INT IDENTITY(1,1) PRIMARY KEY,
    Documento_Identidad VARCHAR(20) NOT NULL UNIQUE,
    Nombre_Completo VARCHAR(100) NOT NULL,
    Segmento VARCHAR(20) NOT NULL CHECK (Segmento IN ('Nuevo', 'Recurrente', 'VIP'))
);

-- Dimensión: Estructura de Tiempo Analítico
CREATE TABLE D_TIEMPO (
    IdTiempo INT PRIMARY KEY, -- Formato Clave: YYYYMMDD
    Fecha DATE NOT NULL,
    Anio INT NOT NULL,
    Mes INT NOT NULL,
    Dia INT NOT NULL,
    Es_Evento BIT NOT NULL DEFAULT 0 
);

-- Dimensión: Cobertura Geográfica de Despacho
CREATE TABLE D_GEOGRAFIA (
    IdGeografia INT IDENTITY(1,1) PRIMARY KEY,
    Departamento VARCHAR(50) NOT NULL,
    Provincia VARCHAR(50) NOT NULL,
    Distrito VARCHAR(50) NOT NULL,
    Zona_Logistica VARCHAR(20) NOT NULL CHECK (Zona_Logistica IN ('Lima', 'Norte', 'Sur', 'Centro'))
);

-- Dimensión: Sucursales y Canales de Distribución
CREATE TABLE D_SUCURSALES (
    IdSucursal INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Sucursal VARCHAR(50) NOT NULL,
    Canal VARCHAR(20) NOT NULL CHECK (Canal IN ('E-commerce', 'Presencial'))
);

-- Dimensión: Gestión Estratégica de Promociones
CREATE TABLE D_PROMOCIONES (
    IdPromocion INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Promo VARCHAR(50) NOT NULL,
    Tipo_Descuento VARCHAR(20) NOT NULL,
    Valor_Descuento DECIMAL(12,2) DEFAULT 0.00
);

-- Dimensión: Modalidades y Métodos de Pago
CREATE TABLE D_METODOS_PAGO (
    IdMetodoPago INT IDENTITY(1,1) PRIMARY KEY,
    Descripcion VARCHAR(50) NOT NULL
);

-- Tabla de Hechos Lógica: Flujo de Ventas Masivas
CREATE TABLE FACT_VENTAS (
    IdVenta INT IDENTITY(1,1) PRIMARY KEY,
    IdProducto INT NOT NULL FOREIGN KEY REFERENCES D_PRODUCTOS(IdProducto),
    IdCliente INT NOT NULL FOREIGN KEY REFERENCES D_CLIENTES(IdCliente),
    IdTiempo INT NOT NULL FOREIGN KEY REFERENCES D_TIEMPO(IdTiempo),
    IdGeografia INT NOT NULL FOREIGN KEY REFERENCES D_GEOGRAFIA(IdGeografia),
    IdSucursal INT NOT NULL FOREIGN KEY REFERENCES D_SUCURSALES(IdSucursal),
    IdPromocion INT NOT NULL FOREIGN KEY REFERENCES D_PROMOCIONES(IdPromocion),
    IdMetodoPago INT NOT NULL FOREIGN KEY REFERENCES D_METODOS_PAGO(IdMetodoPago),
    Cantidad INT NOT NULL CHECK (Cantidad >= 0), -- Permite 0 para manejar devoluciones de stock
    Monto_Bruto DECIMAL(12,2) NOT NULL,
    Monto_Descuento DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    Monto_Neto DECIMAL(12,2) NOT NULL,
    CONSTRAINT CK_MontoNetoReal CHECK (Monto_Neto = (Monto_Bruto - Monto_Descuento)) -- Sintaxis corregida aquí
);
GO

---------- INSERTS ----------

INSERT INTO D_SUCURSALES (Nombre_Sucursal, Canal) VALUES
('Plataforma Web Nacional', 'E-commerce'),
('Tienda Física CC Jockey Plaza', 'Presencial'),
('Tienda Física Real Plaza Arequipa', 'Presencial'),
('Tienda Física Mall Aventura Trujillo', 'Presencial');

INSERT INTO D_PROMOCIONES (Nombre_Promo, Tipo_Descuento, Valor_Descuento) VALUES
('Sin Promoción / Precio Regular', 'Monto Fijo', 0.00),
('Campaña Cyber Wow Mayo', 'Porcentaje', 15.00),
('Descuento Black Friday', 'Porcentaje', 20.00),
('Cupón Gamer Extremo', 'Monto Fijo', 100.00),
('Campaña Back to School', 'Porcentaje', 10.00);

INSERT INTO D_METODOS_PAGO (Descripcion) VALUES
('Tarjeta Credito'), ('Tarjeta Debito'), ('Yape'), ('Plin'), ('Efectivo');

-- Carga estructurada de la Dimensión Tiempo cubriendo fechas estratégicas (2023 - 2025)
INSERT INTO D_TIEMPO (IdTiempo, Fecha, Anio, Mes, Dia, Es_Evento) VALUES
(20230515, '2023-05-15', 2023, 5, 15, 0),
(20231124, '2023-11-24', 2023, 11, 24, 1), -- Black Friday 2023
(20240310, '2024-03-10', 2024, 3, 10, 1),  -- Back to School 2024
(20240522, '2024-05-22', 2024, 5, 22, 1),  -- Cyber Wow 2024
(20241129, '2024-11-29', 2024, 11, 29, 1), -- Black Friday 2024
(20250220, '2025-02-20', 2025, 2, 20, 1),  -- Back to School 2025
(20250514, '2025-05-14', 2025, 5, 14, 1),  -- Cyber Wow 2025
(20250718, '2025-07-18', 2025, 7, 18, 0);
GO


--------- PROCESOS DE ALMACENADO ---------

-- Automatización Maestro de Catálogo Tecnológico
CREATE PROCEDURE dbo.USP_RegistrarProducto
    @SKU VARCHAR(50), @NombreProducto VARCHAR(100), @Categoria VARCHAR(50), @Marca VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM D_PRODUCTOS WHERE SKU = @SKU)
        BEGIN
            PRINT 'El SKU ingresado ya existe en la dimensión de hardware.';
            RETURN;
        END
        INSERT INTO D_PRODUCTOS (SKU, NombreProducto, Categoria, Marca)
        VALUES (@SKU, @NombreProducto, @Categoria, @Marca);
    END TRY
    BEGIN CATCH
        PRINT 'Error crítico en USP_RegistrarProducto: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

-- Automatización Maestro de Clientes y Segmentos
CREATE PROCEDURE dbo.USP_RegistrarCliente
    @DocumentoIdentidad VARCHAR(20), @NombreCompleto VARCHAR(100), @Segmento VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @Segmento NOT IN ('Nuevo', 'Recurrente', 'VIP')
        BEGIN
            PRINT 'Error de Negocio: Segmento no parametrizado en la regla de negocio.';
            RETURN;
        END
        IF EXISTS (SELECT 1 FROM D_CLIENTES WHERE Documento_Identidad = @DocumentoIdentidad)
        BEGIN
            PRINT 'El documento de identidad del comprador ya existe.';
            RETURN;
        END
        INSERT INTO D_CLIENTES (Documento_Identidad, Nombre_Completo, Segmento)
        VALUES (@DocumentoIdentidad, @NombreCompleto, @Segmento);
    END TRY
    BEGIN CATCH
        PRINT 'Error crítico en USP_RegistrarCliente: ' + ERROR_MESSAGE();
    END CATCH
END;
GO


-- ========================================================================
-- PARTE 4: FUNCIONES Y PROCEDIMIENTOS DE CONTROL LOGÍSTICO Y TRANSACCIONAL
-- ========================================================================

-- Función Avanzada (UDF): Validación de Ventanas de Inactividad Comercial (Fuga de Clientes)
CREATE FUNCTION dbo.F_VerificarClienteInactivo (
    @IdCliente INT,
    @FechaCorte DATE
)
RETURNS BIT
AS
BEGIN
    DECLARE @Resultado BIT = 0;
    DECLARE @UltimaCompra DATE;

    SELECT @UltimaCompra = MAX(t.Fecha)
    FROM FACT_VENTAS f
    INNER JOIN D_TIEMPO t ON f.IdTiempo = t.IdTiempo
    WHERE f.IdCliente = @IdCliente;

    -- Si no registra compras históricas o su brecha de consumo supera los 60 días naturales
    IF @UltimaCompra IS NULL OR DATEDIFF(DAY, @UltimaCompra, @FechaCorte) > 60
        SET @Resultado = 1;

    RETURN @Resultado;
END;
GO

-- SP 4.1: Inyección Masiva e Inteligente de la Tabla de Hechos (Cruces Dinámicos de Llaves)
CREATE PROCEDURE dbo.USP_RegistrarVenta
    @SKU VARCHAR(50), @DocumentoIdentidad VARCHAR(20), @FechaVenta DATE,
    @Departamento VARCHAR(50), @Provincia VARCHAR(50), @Distrito VARCHAR(50), @ZonaLogistica VARCHAR(20),
    @Sucursal VARCHAR(50), @Promocion VARCHAR(50), @MetodoPago VARCHAR(50),
    @Cantidad INT, @MontoBruto DECIMAL(12,2), @MontoDescuento DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdProducto INT, @IdCliente INT, @IdTiempo INT, @IdGeografia INT;
        DECLARE @IdSucursal INT, @IdPromocion INT, @IdMetodoPago INT;
        DECLARE @MontoNeto DECIMAL(12,2) = @MontoBruto - @MontoDescuento;

        -- Resolución dinámica de llaves sustitutas por cruce analítico
        SELECT @IdProducto = IdProducto FROM D_PRODUCTOS WHERE SKU = @SKU;
        SELECT @IdCliente = IdCliente FROM D_CLIENTES WHERE Documento_Identidad = @DocumentoIdentidad;
        SELECT @IdSucursal = IdSucursal FROM D_SUCURSALES WHERE Nombre_Sucursal = @Sucursal;
        SELECT @IdPromocion = IdPromocion FROM D_PROMOCIONES WHERE Nombre_Promo = @Promocion;
        SELECT @IdMetodoPago = IdMetodoPago FROM D_METODOS_PAGO WHERE Descripcion = @MetodoPago;

        -- Inyección o normalización de la dimensión Geografía si ocurre un cambio zonal
        SELECT @IdGeografia = IdGeografia FROM D_GEOGRAFIA 
        WHERE Departamento = @Departamento AND Provincia = @Provincia AND Distrito = @Distrito;
        
        IF @IdGeografia IS NULL
        BEGIN
            INSERT INTO D_GEOGRAFIA (Departamento, Provincia, Distrito, Zona_Logistica)
            VALUES (@Departamento, @Provincia, @Distrito, @ZonaLogistica);
            SET @IdGeografia = SCOPE_IDENTITY();
        END

        -- Formatear llave secuencial temporal inteligente (YYYYMMDD)
        SET @IdTiempo = CAST(CONVERT(VARCHAR(8), @FechaVenta, 112) AS INT);

        INSERT INTO FACT_VENTAS (IdProducto, IdCliente, IdTiempo, IdGeografia, IdSucursal, IdPromocion, IdMetodoPago, Cantidad, Monto_Bruto, Monto_Descuento, Monto_Neto)
        VALUES (@IdProducto, @IdCliente, @IdTiempo, @IdGeografia, @IdSucursal, @IdPromocion, @IdMetodoPago, @Cantidad, @MontoBruto, @MontoDescuento, @MontoNeto);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error en la inyección transaccional del Data Mart: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

-- SP 4.2: Gestión y Mitigación de Pérdidas por Devoluciones de Hardware defectuoso
CREATE PROCEDURE dbo.USP_ProcesarDevolucionHardware
    @IdVenta INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM FACT_VENTAS WHERE IdVenta = @IdVenta)
        BEGIN
            PRINT 'Error: Transacción de venta no rastreada.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Recular a cero los montos económicos para no alterar falsamente los KPIs de ganancia neta
        UPDATE FACT_VENTAS
        SET Cantidad = 0, Monto_Bruto = 0.00, Monto_Descuento = 0.00, Monto_Neto = 0.00
        WHERE IdVenta = @IdVenta;

        COMMIT TRANSACTION;
        PRINT 'Devolución técnica procesada. Registro recalculado a cero en el cubo.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error crítico en flujo de devoluciones: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

-- SP 4.3: Proceso con Cursor Analítico para el Escaneo Masivo del Churn Rate
CREATE PROCEDURE dbo.USP_AuditarChurnClientes
    @FechaAnalisis DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdCliente INT, @Nombre VARCHAR(100), @EsInactivo BIT;
    
    DECLARE CursorClientes CURSOR FOR 
    SELECT IdCliente, Nombre_Completo FROM D_CLIENTES;
    
    OPEN CursorClientes;
    FETCH NEXT FROM CursorClientes INTO @IdCliente, @Nombre;
    
    PRINT '========================================================================';
    PRINT 'REPORTE CORPORATIVO DE ALERTAS: CONTROL DE CHURN RATE AL ' + CAST(@FechaAnalisis AS VARCHAR);
    PRINT '========================================================================';

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EsInactivo = dbo.F_VerificarClienteInactivo(@IdCliente, @FechaAnalisis);
        
        IF @EsInactivo = 1
        BEGIN
            PRINT 'ALERTA DESERCIÓN: El cliente [ID: ' + CAST(@IdCliente AS VARCHAR) + '] - ' + @Nombre + ' se encuentra en RIESGO DE FUGA.';
        END
        
        FETCH NEXT FROM CursorClientes INTO @IdCliente, @Nombre;
    END
    
    CLOSE CursorClientes;
    DEALLOCATE CursorClientes;
    PRINT '========================================================================';
END;
GO


-- ========================================================================
-- PARTE 5: POBLADO INTERNO INICIAL DE DATOS MAESTROS (MOCK DATA COMPLETO)
-- ========================================================================

-- Poblado de Dimensión Productos
EXEC dbo.USP_RegistrarProducto 'LAP-GMR-01', 'Laptop Gamer Acer Nitro 5 Intel i7', 'Laptops', 'Acer';
EXEC dbo.USP_RegistrarProducto 'LAP-OFF-02', 'Laptop ASUS Vivobook Ryzen 5', 'Laptops', 'ASUS';
EXEC dbo.USP_RegistrarProducto 'LAP-MAC-03', 'MacBook Air M2 13 Pulgadas', 'Laptops', 'Apple';
EXEC dbo.USP_RegistrarProducto 'SSD-1TB-01', 'Disco Sólido Kingston NVMe 1TB', 'Almacenamiento', 'Kingston';
EXEC dbo.USP_RegistrarProducto 'SSD-2TB-02', 'Disco Sólido Samsung EVO 2TB', 'Almacenamiento', 'Samsung';
EXEC dbo.USP_RegistrarProducto 'RAM-16G-01', 'Memoria RAM Corsair Vengeance 16GB DDR4', 'Componentes', 'Corsair';
EXEC dbo.USP_RegistrarProducto 'GPU-RTX-40', 'Tarjeta de Video MSI RTX 4060 Ti 8GB', 'Componentes', 'MSI';
EXEC dbo.USP_RegistrarProducto 'MNT-GMR-27', 'Monitor Gamer LG 27 UltraGear FHD', 'Monitores', 'LG';
EXEC dbo.USP_RegistrarProducto 'MOU-LOG-G5', 'Mouse Logitech G502 Hero Lightspeed', 'Periféricos', 'Logitech';
EXEC dbo.USP_RegistrarProducto 'KEY-HYP-ALL', 'Teclado Mecánico HyperX Alloy Origins', 'Periféricos', 'HyperX';

-- Poblado de Dimensión Clientes
EXEC dbo.USP_RegistrarCliente '71234567', 'Carlos Mendoza Ruiz', 'VIP';
EXEC dbo.USP_RegistrarCliente '45321678', 'Ana Gabriel Flores', 'Recurrente';
EXEC dbo.USP_RegistrarCliente '09876543', 'Jean Pierre Claux', 'Nuevo';
EXEC dbo.USP_RegistrarCliente '76543210', 'Milagros Soto Palomino', 'Recurrente';
EXEC dbo.USP_RegistrarCliente '41253698', 'Renato Castillos Vega', 'VIP';
EXEC dbo.USP_RegistrarCliente '73418529', 'Fiorella Beltrán Arce', 'Nuevo';
EXEC dbo.USP_RegistrarCliente '10293847', 'Diego Torres Navarro', 'Recurrente';
EXEC dbo.USP_RegistrarCliente '49586712', 'Estefanía Wong Guerrero', 'VIP';
EXEC dbo.USP_RegistrarCliente '70615243', 'Pedro Picapiedra Prado', 'Nuevo';
EXEC dbo.USP_RegistrarCliente '44332211', 'Ximena Dávila Ugarte', 'Recurrente';

-- Inyección Masiva a la Tabla de Hechos (FACT_VENTAS) Cruzando el Historial 2023 - 2025
EXEC dbo.USP_RegistrarVenta 'LAP-GMR-01', '71234567', '2023-05-15', 'Lima', 'Lima', 'San Isidro', 'Lima', 'Tienda Física CC Jockey Plaza', 'Sin Promoción / Precio Regular', 'Tarjeta Credito', 1, 4200.00, 0.00;
EXEC dbo.USP_RegistrarVenta 'SSD-1TB-01', '45321678', '2023-05-15', 'Arequipa', 'Arequipa', 'Cayma', 'Sur', 'Tienda Física Real Plaza Arequipa', 'Sin Promoción / Precio Regular', 'Yape', 2, 640.00, 0.00;
EXEC dbo.USP_RegistrarVenta 'GPU-RTX-40', '41253698', '2023-11-24', 'Lima', 'Lima', 'Miraflores', 'Lima', 'Plataforma Web Nacional', 'Descuento Black Friday', 'Tarjeta Credito', 1, 1850.00, 370.00;
EXEC dbo.USP_RegistrarVenta 'LAP-OFF-02', '09876543', '2024-03-10', 'La Libertad', 'Trujillo', 'Víctor Larco Herrera', 'Norte', 'Tienda Física Mall Aventura Trujillo', 'Campaña Back to School', 'Tarjeta Debito', 5, 12500.00, 1250.00;
EXEC dbo.USP_RegistrarVenta 'LAP-GMR-01', '76543210', '2024-05-22', 'Lima', 'Lima', 'Los Olivos', 'Lima', 'Plataforma Web Nacional', 'Campaña Cyber Wow Mayo', 'Tarjeta Credito', 2, 8400.00, 1260.00;
EXEC dbo.USP_RegistrarVenta 'RAM-16G-01', '73418529', '2024-05-22', 'Junín', 'Huancayo', 'El Tambo', 'Centro', 'Tienda Física CC Jockey Plaza', 'Sin Promoción / Precio Regular', 'Efectivo', 3, 630.00, 0.00;
EXEC dbo.USP_RegistrarVenta 'LAP-MAC-03', '49586712', '2024-11-29', 'Piura', 'Piura', 'Castilla', 'Norte', 'Plataforma Web Nacional', 'Descuento Black Friday', 'Tarjeta Credito', 1, 5100.00, 1020.00;
EXEC dbo.USP_RegistrarVenta 'SSD-2TB-02', '10293847', '2025-02-20', 'Cusco', 'Cusco', 'Wanchaq', 'Sur', 'Tienda Física Real Plaza Arequipa', 'Campaña Back to School', 'Tarjeta Debito', 2, 1360.00, 136.00;
EXEC dbo.USP_RegistrarVenta 'GPU-RTX-40', '71234567', '2025-05-14', 'Lima', 'Lima', 'San Isidro', 'Lima', 'Plataforma Web Nacional', 'Campaña Cyber Wow Mayo', 'Plin', 2, 3700.00, 555.00;
EXEC dbo.USP_RegistrarVenta 'LAP-OFF-02', '70615243', '2025-07-18', 'Lambayeque', 'Chiclayo', 'Pimentel', 'Norte', 'Tienda Física Mall Aventura Trujillo', 'Cupón Gamer Extremo', 'Tarjeta Credito', 1, 2500.00, 100.00;
EXEC dbo.USP_RegistrarVenta 'MNT-GMR-27', '44332211', '2025-05-14', 'Lima', 'Lima', 'Miraflores', 'Lima', 'Plataforma Web Nacional', 'Campaña Cyber Wow Mayo', 'Tarjeta Credito', 2, 1900.00, 285.00;
EXEC dbo.USP_RegistrarVenta 'MOU-LOG-G5', '76543210', '2024-05-22', 'Lima', 'Lima', 'Los Olivos', 'Lima', 'Plataforma Web Nacional', 'Campaña Cyber Wow Mayo', 'Yape', 1, 280.00, 42.00;
EXEC dbo.USP_RegistrarVenta 'KEY-HYP-ALL', '45321678', '2023-11-24', 'Arequipa', 'Arequipa', 'Cayma', 'Sur', 'Tienda Física Real Plaza Arequipa', 'Descuento Black Friday', 'Tarjeta Debito', 2, 780.00, 156.00;
EXEC dbo.USP_RegistrarVenta 'SSD-1TB-01', '41253698', '2024-11-29', 'Lima', 'Lima', 'Miraflores', 'Lima', 'Tienda Física CC Jockey Plaza', 'Sin Promoción / Precio Regular', 'Tarjeta Credito', 10, 3200.00, 0.00;
EXEC dbo.USP_RegistrarVenta 'LAP-GMR-01', '49586712', '2025-05-14', 'Piura', 'Piura', 'Castilla', 'Norte', 'Plataforma Web Nacional', 'Campaña Cyber Wow Mayo', 'Tarjeta Credito', 1, 4200.00, 630.00;
EXEC dbo.USP_RegistrarVenta 'LAP-MAC-03', '45321678', '2024-11-29', 'Ica', 'Ica', 'Parcona', 'Centro', 'Tienda Física Real Plaza Arequipa', 'Descuento Black Friday', 'Tarjeta Debito', 1, 5100.00, 1020.00;
EXEC dbo.USP_RegistrarVenta 'RAM-16G-01', '70615243', '2025-02-20', 'La Libertad', 'Trujillo', 'Víctor Larco Herrera', 'Norte', 'Tienda Física Mall Aventura Trujillo', 'Campaña Back to School', 'Yape', 4, 840.00, 84.00;
GO


-- ========================================================================
-- PARTE 6: CREACIÓN DE VISTAS ANALÍTICAS (CAPA PRE-OLAP FRONTEND)
-- ========================================================================

-- Vista 6.1: Análisis de Tendencia y Crecimiento Financiero YoY
CREATE VIEW V_Analisis_Crecimiento_YoY AS
SELECT 
    t.Anio AS Anio_Fiscal,
    p.Categoria,
    SUM(f.Cantidad) AS Unidades_Vendidas,
    SUM(f.Monto_Bruto) AS Facturacion_Bruta,
    SUM(f.Monto_Descuento) AS Descuentos_Absorbidos,
    SUM(f.Monto_Neto) AS Ingreso_Neto_Real
FROM FACT_VENTAS f
INNER JOIN D_TIEMPO t ON f.IdTiempo = t.IdTiempo
INNER JOIN D_PRODUCTOS p ON f.IdProducto = p.IdProducto
GROUP BY t.Anio, p.Categoria;
GO

-- Vista 6.2: Inteligencia Territorial y Control de Ticket Promedio
CREATE VIEW V_Inteligencia_Territorial AS
SELECT 
    g.Zona_Logistica, g.Departamento, g.Provincia, g.Distrito,
    COUNT(f.IdVenta) AS Total_Transacciones,
    SUM(f.Cantidad) AS Productos_Despachados,
    SUM(f.Monto_Neto) AS Venta_Neta_Total,
    ROUND(SUM(f.Monto_Neto) / COUNT(f.IdVenta), 2) AS Ticket_Promedio_Soles
FROM FACT_VENTAS f
INNER JOIN D_GEOGRAFIA g ON f.IdGeografia = g.IdGeografia
GROUP BY g.Zona_Logistica, g.Departamento, g.Provincia, g.Distrito;
GO

EXEC dbo.USP_AuditarChurnClientes @FechaAnalisis = '2025-09-01';

SELECT * FROM D_PRODUCTOS;
SELECT * FROM D_CLIENTES;
SELECT * FROM D_GEOGRAFIA;


SELECT name FROM sys.procedures WHERE name = 'USP_RegistrarVenta';