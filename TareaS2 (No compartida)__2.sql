-- Declaración de variables de enlace para que SQL Developer las pida al inicio
VARIABLE b_fecha_proceso VARCHAR2(20);
VARIABLE b_id_min NUMBER;
VARIABLE b_id_max NUMBER;

-- Valores por defecto (se pueden cambiar en el cuadro de diálogo)
EXEC :b_fecha_proceso := TO_CHAR(SYSDATE, 'DD/MM/YYYY');
EXEC :b_id_min := 100;
EXEC :b_id_max := 320;

DECLARE
    -- Variables con %TYPE según la tabla EMPLEADO
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

    -- Variables para cálculos
    v_usuario_generado   VARCHAR2(100);
    v_clave_generada     VARCHAR2(100);
    v_antiguedad         NUMBER;
    v_letras_apellido    VARCHAR2(5);
    
    -- Contadores
    v_total_a_procesar   NUMBER := 0;
    v_contador_exito     NUMBER := 0;
    v_fecha_proc_date    DATE;

BEGIN
    -- Limpiar tabla de resultados
    EXECUTE IMMEDIATE 'TRUNCATE TABLE USUARIO_CLAVE';

    v_fecha_proc_date := TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY');

    -- Contar registros reales en el rango para validación final
    SELECT COUNT(*) INTO v_total_a_procesar 
    FROM EMPLEADO 
    WHERE id_emp BETWEEN :b_id_min AND :b_id_max;

    -- Ciclo utilizando las variables de enlace b_id_min y b_id_max
    FOR i IN :b_id_min .. :b_id_max LOOP
        v_id_emp_actual := i;
        
        BEGIN
            -- Obtención de datos con JOIN a ESTADO_CIVIL
            SELECT e.numrun_emp, e.dvrun_emp, e.pnombre_emp, e.appaterno_emp, 
                   e.sueldo_base, e.fecha_nac, e.fecha_contrato, ec.id_estado_civil, ec.nombre_estado_civil
            INTO v_numrun, v_dvrun, v_pnombre, v_appaterno, 
                 v_sueldo_base, v_fecha_nac, v_fecha_contrato, v_id_est_civil, v_nombre_est_civil
            FROM EMPLEADO e
            JOIN ESTADO_CIVIL ec ON e.id_estado_civil = ec.id_estado_civil
            WHERE e.id_emp = v_id_emp_actual;

            -- 1. Cálculo de antigüedad
            v_antiguedad := TRUNC(MONTHS_BETWEEN(v_fecha_proc_date, v_fecha_contrato) / 12);
            
            -- 2. Generación de Nombre de Usuario
            v_usuario_generado := 
                LOWER(SUBSTR(v_nombre_est_civil, 1, 1)) ||       
                SUBSTR(v_pnombre, 1, 3) ||                      
                LENGTH(v_pnombre) ||                            
                '*' ||                                           
                SUBSTR(TO_CHAR(v_sueldo_base), -1) ||            
                v_dvrun ||                                       
                v_antiguedad;                                   
            
            IF v_antiguedad < 10 THEN
                v_usuario_generado := v_usuario_generado || 'X';
            END IF;

            -- 3. Selección de letras del apellido según Estado Civil
            IF v_id_est_civil IN (10, 60) THEN 
                v_letras_apellido := SUBSTR(v_appaterno, 1, 2); 
            ELSIF v_id_est_civil IN (20, 30) THEN
                v_letras_apellido := SUBSTR(v_appaterno, 1, 1) || SUBSTR(v_appaterno, -1); 
            ELSIF v_id_est_civil = 40 THEN 
                v_letras_apellido := SUBSTR(v_appaterno, -3, 2); 
            ELSIF v_id_est_civil = 50 THEN 
                v_letras_apellido := SUBSTR(v_appaterno, -2); 
            ELSE
                v_letras_apellido := 'XX';
            END IF;

            -- 4. Generación de Clave
            v_clave_generada := 
                SUBSTR(TO_CHAR(v_numrun), 3, 1) ||                     
                (EXTRACT(YEAR FROM v_fecha_nac) + 2) ||                 
                (TO_NUMBER(SUBSTR(TO_CHAR(v_sueldo_base), -3)) - 1) ||  
                LOWER(v_letras_apellido) ||                             
                v_id_emp_actual ||                                     
                TO_CHAR(v_fecha_proc_date, 'MMYYYY');                  

            -- CORRECCIÓN DEL ERROR ORA-00947: Especificamos las columnas destino
            INSERT INTO USUARIO_CLAVE (
                id_emp, 
                numrun_emp, 
                dvrun_emp, 
                nombre_empleado, 
                nombre_usuario, 
                clave_usuario
            )
            VALUES (
                v_id_emp_actual, 
                v_numrun, 
                v_dvrun, 
                v_pnombre || ' ' || v_appaterno, 
                v_usuario_generado, 
                v_clave_generada
            );
            
            v_contador_exito := v_contador_exito + 1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN 
                NULL; -- Si el ID de empleado no existe en el rango, saltar al siguiente
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error en ID ' || v_id_emp_actual || ': ' || SQLERRM);
        END;
    END LOOP;

    -- Validación final para COMMIT o ROLLBACK
    IF v_contador_exito = v_total_a_procesar AND v_total_a_procesar > 0 THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Proceso Finalizado Exitosamente. Registros procesados: ' || v_contador_exito);
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: No se procesaron todos los registros esperados. Se aplicó ROLLBACK.');
    END IF;
END;
/