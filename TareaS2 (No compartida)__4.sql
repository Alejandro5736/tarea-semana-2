SELECT 
    e.pnombre_emp, 
    e.appaterno_emp, 
    e.sueldo_base, 
    u.nombre_usuario, 
    u.clave_usuario 
FROM EMPLEADO e
JOIN USUARIO_CLAVE u ON e.id_emp = u.id_emp
WHERE e.id_emp = 110;





SELECT 
    nombre_empleado, 
    clave_usuario 
FROM USUARIO_CLAVE 
WHERE id_emp IN (100, 110, 120); 