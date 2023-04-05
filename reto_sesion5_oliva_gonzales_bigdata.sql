/*	1. Crear un Procedimiento que calcule y devuelva el total de ventas por producto y por año.          */

CREATE PROCEDURE PR_REPORTE_VENTA(@Parametro NVARCHAR(50) = '0') 
AS BEGIN
	IF @Parametro = 'ReporteGeneral' 
	BEGIN
		SELECT
		P.Name AS NOM_PRODUCTO,
		YEAR(SOH.OrderDate) AS PEDIDO_YEAR,
		SUM(SOD.LineTotal) AS VENTAS_TOTALES
		FROM Sales.SalesOrderHeader SOH
		JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
		JOIN Production.Product P ON SOD.ProductID = P.ProductID
		GROUP BY P.Name, YEAR(SOH.OrderDate)
		ORDER BY P.Name ASC, PEDIDO_YEAR DESC;
	END
	ELSE IF ISNUMERIC(@Parametro) = 1 -- Si el parámetro es numérico
	BEGIN
		IF NOT EXISTS (SELECT * FROM Sales.SalesOrderHeader WHERE YEAR(OrderDate) = @Parametro)
			BEGIN
				PRINT 'No hay ventas registradas para el año especificado.'
				END
				ELSE
				BEGIN
					SELECT	P.Name AS NOM_PRODUCTO,
							YEAR(SOH.OrderDate) AS PEDIDO_YEAR,
							SUM(SOD.LineTotal) AS VENTAS_TOTALES
					FROM Sales.SalesOrderHeader SOH
					JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
					JOIN Production.Product P ON SOD.ProductID = P.ProductID
					WHERE YEAR(SOH.OrderDate) = @Parametro
					GROUP BY P.Name, YEAR(SOH.OrderDate)
					ORDER BY VENTAS_TOTALES DESC;
				END
			END
		ELSE -- Si el parámetro no es numérico
		BEGIN
			IF NOT EXISTS (SELECT * FROM Production.Product WHERE Name = @Parametro)
			BEGIN
			PRINT 'El producto especificado no existe.'
		END
		ELSE
		BEGIN
			SELECT	P.Name AS NOM_PRODUCTO,
					YEAR(SOH.OrderDate) AS PEDIDO_YEAR,
					SUM(SOD.LineTotal) AS VENTAS_TOTALES
			FROM Sales.SalesOrderHeader SOH
			JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
			JOIN Production.Product P ON SOD.ProductID = P.ProductID
			WHERE P.Name = @Parametro
			GROUP BY P.Name, YEAR(SOH.OrderDate)
			ORDER BY VENTAS_TOTALES DESC;
		END
	END
END
-- consultando registros ...

EXEC PR_REPORTE_VENTA 'ReporteGeneral'
EXEC PR_REPORTE_VENTA '2011'
EXEC PR_REPORTE_VENTA 'Road-150 Red, 56'

-- Procedimiento para encontrar la venta total de un producto en un año en especifico:
CREATE PROCEDURE PR_REPORTE_VENTA_PRODUCTO_POR_ANIO @NOM_PRODUCTO NVARCHAR(50), @ANIO INT AS
BEGIN
    IF NOT EXISTS(SELECT 1 FROM Production.Product WHERE Name = @NOM_PRODUCTO)
    BEGIN
        PRINT 'ERROR: El producto no existe en la Base de Datos.'
        RETURN
    END

    IF NOT EXISTS(SELECT 1 FROM Sales.SalesOrderHeader WHERE YEAR(OrderDate) = @ANIO)
    BEGIN
        PRINT 'ERROR: La fecha indicada no existe en la Base de Datos.'
        RETURN
    END
    SELECT	P.Name AS NOM_PRODUCTO, 
			YEAR(SOH.OrderDate) AS PEDIDO_YEAR,
			SUM(SOD.LineTotal) AS VENTAS_TOTALES
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
    JOIN Production.Product P ON SOD.ProductID = P.ProductID
    WHERE P.Name = @NOM_PRODUCTO AND YEAR(SOH.OrderDate) = @ANIO
    GROUP BY P.Name, YEAR(SOH.OrderDate)
    ORDER BY VENTAS_TOTALES DESC;
END
-- consultando registro ...
EXEC PR_REPORTE_VENTA_PRODUCTO_POR_ANIO 'Road-150 Red, 56','2011'


/*	2. Crear un procedimiento almacenado que permita buscar y retornar información de un cliente 
	en base al número de teléfono, este retornará: nombre, apellido, número de teléfono, dirección
	y la suma del valor total de las 2 últimas compras.                                                  */

CREATE PROCEDURE PR_BUSCAR_CLIENTE_POR_NUMERO @NUM_TELEFONO NVARCHAR(25) AS
BEGIN
  SET NOCOUNT ON;
  -- Busca la información del cliente según el número de teléfono
  SELECT	p.BusinessEntityID,
			FirstName, 
			LastName, 
			PhoneNumber, 
			AddressLine1, 
			City, 
			PostalCode
  INTO #CLIENTES
  FROM Person.PersonPhone PT
  JOIN Person.Person P ON PT.BusinessEntityID = P.BusinessEntityID
  JOIN Person.BusinessEntityAddress BEA ON P.BusinessEntityID = BEA.BusinessEntityID
  JOIN Person.Address A ON BEA.AddressID = A.AddressID
  WHERE PT.PhoneNumber = @NUM_TELEFONO;
  -- Si no se encuentra ningún cliente, devuelve un mensaje de error
  IF @@ROWCOUNT = 0
  BEGIN
       PRINT 'ERROR: No se encontró ningún cliente con el número de teléfono especificado.'
    RETURN
  END
  -- Busca las últimas dos órdenes del cliente y calcula el valor total de las dos órdenes
  SELECT 
    C.FirstName, C.LastName, C.PhoneNumber, C.AddressLine1, C.City, C.PostalCode, 
    SUM(SOD.LineTotal) AS ULTIMOS_PEDIDOS
  FROM Sales.SalesOrderHeader SOH
  JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
  JOIN (	SELECT TOP 2 SalesOrderID, CustomerID
			FROM Sales.SalesOrderHeader
			WHERE CustomerID = (SELECT TOP 1 BusinessEntityID FROM #CLIENTES)
			ORDER BY OrderDate DESC
		) AS ORDENES_RECIENTES 
		  ON SOH.SalesOrderID = ORDENES_RECIENTES.SalesOrderID
  JOIN #CLIENTES C ON C.BusinessEntityID = ORDENES_RECIENTES.CustomerID
  GROUP BY C.FirstName, C.LastName, C.PhoneNumber, C.AddressLine1, C.City, C.PostalCode;
  -- Elimina la tabla temporal
  DROP TABLE #CLIENTES;
END
-- consultando registros . . .
EXEC PR_BUSCAR_CLIENTE_POR_NUMERO '635-555-0118'

/*	3. Crear una función que devuelva el número total de productos vendidos por un vendedor en un 
	AÑO determinado.                                                                                     */

CREATE FUNCTION PR_TOTAL_PRODUCTOS_VENDIDOS_POR_VENDEDOR_POR_ANIO( 
	@NOM_VENDEDOR NVARCHAR(50), -- nmbre del vendedor
	@APEL_VENDEDOR NVARCHAR(50), -- apellido del vendedor
	@YEAR INT -- año para el que se desea obtener el total de productos vendidos 
)
RETURNS TABLE -- devuelve una tabla con los resultados
AS
RETURN
(
    SELECT 
        P.FirstName, -- Nombre del vendedor
        P.LastName, -- Apellido del vendedor
        YEAR(SOH.OrderDate) AS PEDIDO_YEAR, -- OrderDate = fecha de la orden
        SUM(SOD.OrderQty) AS TOTAL_PRODUCTOS_VENDIDOS	-- OrderQty = cantidad de pedidos 
    FROM Sales.SalesOrderHeader SOH
    JOIN Sales.SalesPerson SP ON SOH.SalesPersonID = SP.BusinessEntityID
    JOIN Person.Person P ON SP.BusinessEntityID = P.BusinessEntityID
    JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
    WHERE P.FirstName = @NOM_VENDEDOR AND P.LastName = @APEL_VENDEDOR -- filtrar por nombre y apellido del vendedor
        AND YEAR(SOH.OrderDate) = @YEAR -- filtrar por año de la venta
    GROUP BY P.FirstName, P.LastName, YEAR(SOH.OrderDate) -- Agrupar por nombre del vendedor, apellido del vendedor y año de la venta
);
--consultando un registro:
SELECT * FROM PR_TOTAL_PRODUCTOS_VENDIDOS_POR_VENDEDOR_POR_ANIO('Jillian', 'Carson', 2011);
SELECT * FROM PR_TOTAL_PRODUCTOS_VENDIDOS_POR_VENDEDOR_POR_ANIO('Jillian', 'Carson', 2014);

/*	4. Crear un procedimiento que según el ID de un producto actualizará el StandardCost, al hacer esto 
	también se deberá actualizar la tabla histórica de este.                                             */

CREATE PROCEDURE PR_ACTUALIZAR_COSTO_PRODUCTO_HISTORICO @id_producto INT, @nuevo_costo FLOAT AS
BEGIN
    IF @nuevo_costo IS NULL OR @nuevo_costo < 0
    BEGIN
        PRINT 'ERROR: El nuevo costo debe ser un valor positivo y no nulo';
        RETURN; -- Salir del procedimiento almacenado
    END

    BEGIN TRANSACTION; -- Iniciar transacción
		-- Actualizar el StandardCost del producto
		UPDATE Production.Product
		SET StandardCost = @nuevo_costo
		WHERE ProductID = @id_producto;

		-- Verificar si se actualizó alguna fila en la tabla Product
		IF @@ROWCOUNT = 0
		BEGIN
			PRINT 'ERROR: No se encontró ningún producto con el ID proporcionado';
			ROLLBACK TRANSACTION; -- Deshacer transacción
			RETURN; -- Salir del procedimiento almacenado
		END

		-- Actualizar la fecha de finalización en el registro anterior
		UPDATE Production.ProductCostHistory
		SET EndDate = GETDATE(), ModifiedDate = GETDATE()
		WHERE ProductID = @id_producto AND EndDate IS NULL

		-- Insertar un nuevo registro en la tabla ProductCostHistory
		INSERT INTO Production.ProductCostHistory (ProductID, StartDate, StandardCost, EndDate, ModifiedDate)
		VALUES (@id_producto, GETDATE(), @nuevo_costo, NULL, GETDATE())

    COMMIT TRANSACTION -- Confirmar transacción
END

-- insertar
EXEC PR_ACTUALIZAR_COSTO_PRODUCTO_HISTORICO @id_producto = '725', @nuevo_costo = '55';

---CONSULTAR

SELECT * FROM Production.Product WHERE ProductID = 725; --- MUESTRA LA TABLA PRODUCTO GENERAL
SELECT * FROM Production.ProductCostHistory WHERE ProductID = 725;  --MUESTRA EL HISTORIA DEL PRODUCTOID
DELETE FROM Production.ProductCostHistory WHERE StandardCost=33; --ELIMINAR DE ACUERDO AL PRECIO
