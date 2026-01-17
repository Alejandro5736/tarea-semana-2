/* ==========================================================================
   EVALUACIÓN SUMATIVA SEMANA 2 - BLOQUE PL/SQL ANÓNIMO
   AUTOR: [Tu Nombre]
   DESCRIPCIÓN: Proceso de generación automática de credenciales (Usuario y Clave)
                para empleados de Truck Rental, con lógica de seguridad y
                validación transaccional.
   ========================================================================== */

/* DEFINICIÓN DE VARIABLES BIND (REQUERIMIENTO B) */
VARIABLE b_fecha_proceso VARCHAR2(20);
VARIABLE b_id_min NUMBER;
VARIABLE b_id_max NUMBER;

/* ASIGNACIÓN DE VALORES (INPUTS) */
/* Se utiliza la fecha indicada en la imagen de referencia o la actual */
EXEC :b_fecha_proceso := '10/03/2027'; 
EXEC :b_id_min := 100;
EXEC :b_id_max := 320;

DECLARE
    /* USO DE %TYPE PARA VARIABLES ESCALARES (REQUERIMIENTO B) */
    v_id_emp_actual      EMPLEADO.id_emp%TYPE;
    v_numrun             EMPLEADO.numrun_emp%TYPE;
    v_dvrun              EMPLEADO.dvrun_emp%TYPE;
    v_pnombre            EMPLEADO.pnombre_emp%TYPE;
    v_appaterno          EMPLEADO.appaterno_emp%TYPE;
    v_sueldo_base        EMPLEADO.sueldo_base%TYPE;
    v_fecha_nac          EMPLEADO.fecha_nac%TYPE;
    v_fecha_contrato     EMPLEADO.fecha_contrato%TYPE;
    v_id_est_civil       EMPLEADO.id_estado_civil%TYPE;
    v_nombre_est_civil   ESTADO_CIVIL.nombre_estado_civil%TYPE;

    /* VARIABLES PARA CÁLCULOS INTERNOS Y LÓGICA DE NEGOCIO */
    v_usuario_generado   VARCHAR2(100);
    v_clave_generada     VARCHAR2(100);
    v_antiguedad         NUMBER;
    v_letras_apellido    VARCHAR2(5);
    
    /* VARIABLES DE CONTROL DE FLUJO Y TRANSACCIÓN */
    v_total_a_procesar   NUMBER := 0;
    v_contador_exito     NUMBER := 0;
    v_fecha_proc_date    DATE;

BEGIN
    /* -------------------------------------------------------------------------
       [DOCUMENTACIÓN SQL 1]: LIMPIEZA DE TABLA (REQUERIMIENTO G y 5)
       Se utiliza SQL Dinámico para truncar la tabla USUARIO_CLAVE al inicio.
       Esto permite re-ejecutar el proceso manteniendo la tabla limpia.
       ------------------------------------------------------------------------- */
    EXECUTE IMMEDIATE 'TRUNCATE TABLE USUARIO_CLAVE';

    -- Conversión de variable Bind a Date para cálculos matemáticos de fechas
    v_fecha_proc_date := TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY');

    /* -------------------------------------------------------------------------
       [DOCUMENTACIÓN SQL 2]: VALIDACIÓN DE INTEGRIDAD
       Obtenemos el conteo total de empleados en el rango antes de procesar
       para compararlo al final y decidir si hacemos COMMIT o ROLLBACK.
       ------------------------------------------------------------------------- */
    SELECT COUNT(*) INTO v_total_a_procesar 
    FROM EMPLEADO 
    WHERE id_emp BETWEEN :b_id_min AND :b_id_max;

    /* INICIO DE ITERACIÓN (REQUERIMIENTO A) */
    FOR i IN :b_id_min .. :b_id_max LOOP
        v_id_emp_actual := i;
        
        BEGIN
            -- Recuperación de datos del empleado actual
            SELECT e.numrun_emp, e.dvrun_emp, e.pnombre_emp, e.appaterno_emp, 
                   e.sueldo_base, e.fecha_nac, e.fecha_contrato, ec.id_estado_civil, ec.nombre_estado_civil
            INTO v_numrun, v_dvrun, v_pnombre, v_appaterno, 
                 v_sueldo_base, v_fecha_nac, v_fecha_contrato, v_id_est_civil, v_nombre_est_civil
            FROM EMPLEADO e
            JOIN ESTADO_CIVIL ec ON e.id_estado_civil = ec.id_estado_civil
            WHERE e.id_emp = v_id_emp_actual;

            /* -----------------------------------------------------------------
               [DOCUMENTACIÓN PL/SQL 1]: CÁLCULO DE ANTIGÜEDAD (REQUERIMIENTO C)
               Se calculan los años de servicio usando MONTHS_BETWEEN dividido por 12.
               Se usa TRUNC para asegurar un valor entero (sin decimales).
               ----------------------------------------------------------------- */
            v_antiguedad := TRUNC(MONTHS_BETWEEN(v_fecha_proc_date, v_fecha_contrato) / 12);
            
            -- LÓGICA DE USUARIO
            -- Composición: 1ra letra Est.Civil + 3 letras Nombre + Largo Nombre + '*' + Ultimo digito sueldo + DV + Antigüedad
            v_usuario_generado := 
                LOWER(SUBSTR(v_nombre_est_civil, 1, 1)) ||       
                SUBSTR(v_pnombre, 1, 3) ||                      
                LENGTH(v_pnombre) ||                            
                '*' ||                                           
                SUBSTR(TO_CHAR(v_sueldo_base), -1) ||            
                v_dvrun ||                                       
                v_antiguedad;                                   
            
            -- Regla condicional: Si es menor a 10 años, se agrega una 'X' al final
            IF v_antiguedad < 10 THEN
                v_usuario_generado := v_usuario_generado || 'X';
            END IF;

            /* -----------------------------------------------------------------
               [DOCUMENTACIÓN PL/SQL 2]: LÓGICA CONDICIONAL COMPLEJA PARA CLAVE
               Se determina qué letras del apellido usar basándose en el ID del Estado Civil.
               IDs: 10(Casado), 20(Divorciado), 30(Soltero), 40(Viudo), 50(Separado), 60(AUC).
               ----------------------------------------------------------------- */
            IF v_id_est_civil IN (10, 60) THEN 
                v_letras_apellido := SUBSTR(v_appaterno, 1, 2); -- Dos primeras
            ELSIF v_id_est_civil IN (20, 30) THEN 
                v_letras_apellido := SUBSTR(v_appaterno, 1, 1) || SUBSTR(v_appaterno, -1); -- Primera y última
            ELSIF v_id_est_civil = 40 THEN 
                v_letras_apellido := SUBSTR(v_appaterno, -3, 2); -- Antepenúltima y penúltima
            ELSIF v_id_est_civil = 50 THEN 
                v_letras_apellido := SUBSTR(v_appaterno, -2); -- Dos últimas
            ELSE
                v_letras_apellido := 'XX'; 
            END IF;

            -- CONSTRUCCIÓN FINAL DE CLAVE
            v_clave_generada := 
                SUBSTR(TO_CHAR(v_numrun), 3, 1) ||                     
                (EXTRACT(YEAR FROM v_fecha_nac) + 2) ||                 
                (TO_NUMBER(SUBSTR(TO_CHAR(v_sueldo_base), -3)) - 1) ||  
                LOWER(v_letras_apellido) ||                             
                v_id_emp_actual ||                                     
                TO_CHAR(v_fecha_proc_date, 'MMYYYY');                  

            -- INSERCIÓN DEL REGISTRO PROCESADO
            INSERT INTO USUARIO_CLAVE (
                id_emp, numrun_emp, dvrun_emp, nombre_empleado, nombre_usuario, clave_usuario
            )
            VALUES (
                v_id_emp_actual, v_numrun, v_dvrun, v_pnombre || ' ' || v_appaterno, v_usuario_generado, v_clave_generada
            );
            
            v_contador_exito := v_contador_exito + 1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN 
                -- Se controla la excepción para saltar los IDs que no existen (huecos en la secuencia)
                NULL; 
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error procesando empleado ID ' || v_id_emp_actual || ': ' || SQLERRM);
        END;
    END LOOP;

    /* -------------------------------------------------------------------------
       CONFIRMACIÓN DE TRANSACCIÓN (REQUERIMIENTO I)
       Solo hacemos COMMIT si la cantidad de insertados coincide con la esperada.
       ------------------------------------------------------------------------- */
    IF v_contador_exito = v_total_a_procesar AND v_total_a_procesar > 0 THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Proceso Finalizado Exitosamente. Registros procesados: ' || v_contador_exito);
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: Inconsistencia en cantidad de registros. Se aplicó ROLLBACK.');
        DBMS_OUTPUT.PUT_LINE('Esperados: ' || v_total_a_procesar || ' - Procesados: ' || v_contador_exito);
    END IF;
END;
/

/* VALIDACIÓN FINAL DE RESULTADOS */
SELECT * FROM USUARIO_CLAVE ORDER BY ID_EMP ASC;