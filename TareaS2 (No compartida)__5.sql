
SELECT COUNT(*) FROM USUARIO_CLAVE;


SELECT * FROM USUARIO_CLAVE FETCH FIRST 5 ROWS ONLY;


SELECT 
    e.fecha_nac, 
    u.clave_usuario 
FROM EMPLEADO e 
JOIN USUARIO_CLAVE u ON e.id_emp = u.id_emp 
WHERE e.id_emp = 100;