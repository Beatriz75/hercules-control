class DatabaseSeed {
  static List<String> get statements => [
        '''
        INSERT INTO employees (name, phone, email, role, store_code, hire_date, status, notes)
        VALUES
        ('Laura Perez', '+52 5551001001', 'laura@hercules.local', 'Cobradora', 'pideHoy', '2025-11-12T00:00:00.000', 'activo', 'Supervisa cartera vencida.'),
        ('Miguel Torres', '+52 5551001002', 'miguel@hercules.local', 'Cobrador', 'mexiOfertas', '2025-10-05T00:00:00.000', 'activo', 'Atiende clientes de alto volumen.'),
        ('Sofia Marin', '+52 5551001003', 'sofia@hercules.local', 'Encargada', 'pideHoy', '2025-09-02T00:00:00.000', 'activo', 'Evalua muestra diaria de leads.'),
        ('Daniel Ruiz', '+52 5551001004', 'daniel@hercules.local', 'Cobrador', 'mexiOfertas', '2025-06-15T00:00:00.000', 'baja', 'Salida por bajo rendimiento.');
        ''',
        '''
        INSERT INTO employee_payments (employee_id, payment_date, amount, concept, payment_method, notes)
        VALUES
        (1, '2026-04-08T00:00:00.000', 220.00, 'Bono cobranza', 'transferencia', 'Cierre semanal.'),
        (2, '2026-04-08T00:00:00.000', 180.00, 'Comision recuperacion', 'efectivo', 'Cobros atrasados.');
        ''',
        '''
        INSERT INTO daily_reviews (review_date, employee_id, store_code, supervisor_name, leads_reviewed, avg_response_minutes, customer_treatment_score, faults_detected, observations, score, used_whatsapp, traceability_risk, additional_criteria)
        VALUES
        ('2026-04-10T00:00:00.000', 1, 'pideHoy', 'Sofia Marin', 6, 18.0, 4.8, 0, 'Buen seguimiento en CRM.', 94.0, 0, 0, 'Trazabilidad correcta'),
        ('2026-04-10T00:00:00.000', 2, 'mexiOfertas', 'Sofia Marin', 5, 37.0, 3.6, 2, 'Uso de WhatsApp Business sin suficiente contexto verificable.', 71.0, 1, 1, 'Se detecto riesgo por canal externo'),
        ('2026-04-09T00:00:00.000', 4, 'mexiOfertas', 'Sofia Marin', 4, 52.0, 3.1, 3, 'Hubo reclamos de clientes por promesas no registradas.', 58.0, 1, 1, 'Revisar auditoria');
        ''',
        '''
        INSERT INTO debts (customer_name, order_code, delivery_date, due_date, amount, status, responsible, store_code, notes)
        VALUES
        ('Andrea Lopez', 'PH-4021', '2026-04-08T00:00:00.000', '2026-04-09T00:00:00.000', 135.50, 'vencido', 'Laura Perez', 'pideHoy', 'Cliente no responde llamadas.'),
        ('Carlos Mena', 'MX-8812', '2026-04-09T00:00:00.000', '2026-04-10T00:00:00.000', 89.90, 'promete pagar', 'Miguel Torres', 'mexiOfertas', 'Promete transferencia hoy.'),
        ('Yanet Rios', 'PH-4026', '2026-04-09T00:00:00.000', '2026-04-10T00:00:00.000', 240.00, 'fraude sospechado', 'Laura Perez', 'pideHoy', 'Entrega con inconsistencias.');
        ''',
        '''
        INSERT INTO phone_lines (phone_number, alias, status, provider, created_at, notes)
        VALUES
        ('+52 5512340001', 'Cobros Norte 1', 'activa', 'Telcel', '2026-01-05T00:00:00.000', 'Uso principal para recuperacion.'),
        ('+52 5512340002', 'Cobros Centro 2', 'activa', 'AT&T', '2026-01-20T00:00:00.000', 'Seguimiento de promesas de pago.'),
        ('+52 5512340003', 'Backup 3', 'inactiva', 'Telcel', '2026-02-12T00:00:00.000', 'Disponible para reasignacion.');
        ''',
        '''
        INSERT INTO line_assignments (line_id, employee_id, assigned_at, status)
        VALUES
        (1, 1, '2026-03-01T00:00:00.000', 'activa'),
        (2, 2, '2026-03-15T00:00:00.000', 'activa');
        ''',
        '''
        INSERT INTO collections (customer_name, order_code, payment_date, amount, method, validated_by, store_code, notes, line_id)
        VALUES
        ('Carlos Mena', 'MX-8812', '2026-04-10T00:00:00.000', 89.90, 'transferencia', 'Sofia Marin', 'mexiOfertas', 'Cobro confirmado tras recordatorio por WhatsApp.', 2),
        ('Luis Ochoa', 'PH-3998', '2026-04-09T00:00:00.000', 120.00, 'efectivo', 'Laura Perez', 'pideHoy', 'Recuperacion en ruta.', 1);
        ''',
        '''
        INSERT INTO reports (type, order_code, customer_name, employee_id, store_code, report_date, description, status, priority, owner, line_id, traceability_risk, external_channel)
        VALUES
        ('cliente no paga', 'PH-4021', 'Andrea Lopez', 1, 'pideHoy', '2026-04-10T00:00:00.000', 'Cliente recibio producto y no completó pago en 24h.', 'abierto', 'alta', 'Sofia Marin', 1, 0, 0),
        ('fraude trabajador', 'MX-7711', 'Marco Diaz', 2, 'mexiOfertas', '2026-04-10T00:00:00.000', 'Se detectaron mensajes sin trazabilidad completa fuera del CRM.', 'en revision', 'critica', 'Direccion Operativa', 2, 1, 1),
        ('paqueteria', 'MX-7705', 'Elena Soto', NULL, 'mexiOfertas', '2026-04-09T00:00:00.000', 'Paquete entregado con demora y evidencia incompleta.', 'abierto', 'media', 'Equipo Logistica', NULL, 0, 0);
        ''',
      ];
}
