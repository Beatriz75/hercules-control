import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/domain/entities/daily_review.dart';

void main() {
  test('daily review exposes risk flag for alert cards', () {
    final review = DailyReview(
      id: 1,
      reviewDate: DateTime(2026, 4, 10),
      employeeId: 7,
      storeCode: 'pideHoy',
      supervisorName: 'Sofia',
      leadsReviewed: 5,
      avgResponseMinutes: 28,
      customerTreatmentScore: 3.5,
      faultsDetected: 2,
      observations: 'Uso de canal externo sin contexto suficiente.',
      score: 70,
      usedWhatsApp: true,
      traceabilityRisk: true,
      additionalCriteria: 'Seguimiento incompleto',
    );

    expect(review.faultsDetected, greaterThan(0));
    expect(review.traceabilityRisk, isTrue);
  });
}
