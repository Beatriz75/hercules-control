class DailyReview {
  const DailyReview({
    required this.id,
    required this.reviewDate,
    required this.employeeId,
    required this.storeCode,
    required this.supervisorName,
    required this.leadsReviewed,
    required this.avgResponseMinutes,
    required this.customerTreatmentScore,
    required this.faultsDetected,
    required this.observations,
    required this.score,
    required this.usedWhatsApp,
    required this.traceabilityRisk,
    required this.additionalCriteria,
  });

  final int? id;
  final DateTime reviewDate;
  final int employeeId;
  final String storeCode;
  final String supervisorName;
  final int leadsReviewed;
  final double avgResponseMinutes;
  final double customerTreatmentScore;
  final int faultsDetected;
  final String observations;
  final double score;
  final bool usedWhatsApp;
  final bool traceabilityRisk;
  final String additionalCriteria;

  factory DailyReview.fromMap(Map<String, Object?> map) {
    return DailyReview(
      id: map['id'] as int?,
      reviewDate: DateTime.parse(map['review_date'] as String),
      employeeId: map['employee_id'] as int,
      storeCode: map['store_code'] as String,
      supervisorName: map['supervisor_name'] as String,
      leadsReviewed: map['leads_reviewed'] as int,
      avgResponseMinutes: (map['avg_response_minutes'] as num).toDouble(),
      customerTreatmentScore:
          (map['customer_treatment_score'] as num).toDouble(),
      faultsDetected: map['faults_detected'] as int,
      observations: map['observations'] as String? ?? '',
      score: (map['score'] as num).toDouble(),
      usedWhatsApp: (map['used_whatsapp'] as int? ?? 0) == 1,
      traceabilityRisk: (map['traceability_risk'] as int? ?? 0) == 1,
      additionalCriteria: map['additional_criteria'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'review_date': reviewDate.toIso8601String(),
      'employee_id': employeeId,
      'store_code': storeCode,
      'supervisor_name': supervisorName,
      'leads_reviewed': leadsReviewed,
      'avg_response_minutes': avgResponseMinutes,
      'customer_treatment_score': customerTreatmentScore,
      'faults_detected': faultsDetected,
      'observations': observations,
      'score': score,
      'used_whatsapp': usedWhatsApp ? 1 : 0,
      'traceability_risk': traceabilityRisk ? 1 : 0,
      'additional_criteria': additionalCriteria,
    };
  }
}
