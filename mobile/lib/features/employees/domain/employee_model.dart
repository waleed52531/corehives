class Employee {
  final String id;
  final String employeeCode;
  final String fullName;
  final String? profilePhotoUrl;
  final String jobTitle;
  final String? departmentId;
  final String employmentType;
  final String employmentStatus;
  final String? personalEmail;
  final String? companyEmail;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String? joiningDate;
  final String? reportingManagerEmployeeId;
  final String? workLocation;
  final String? shiftTiming;
  final String? notes;

  Employee({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    this.profilePhotoUrl,
    required this.jobTitle,
    this.departmentId,
    required this.employmentType,
    required this.employmentStatus,
    this.personalEmail,
    this.companyEmail,
    this.phoneNumber,
    this.whatsappNumber,
    this.joiningDate,
    this.reportingManagerEmployeeId,
    this.workLocation,
    this.shiftTiming,
    this.notes,
  });

  factory Employee.fromMap(String id, Map<String, dynamic> m) => Employee(
        id: id,
        employeeCode: m['employeeCode'] ?? '',
        fullName: m['fullName'] ?? '',
        profilePhotoUrl: m['profilePhotoUrl'],
        jobTitle: m['jobTitle'] ?? '',
        departmentId: m['departmentId'],
        employmentType: m['employmentType'] ?? '',
        employmentStatus: m['employmentStatus'] ?? 'Active',
        personalEmail: m['personalEmail'],
        companyEmail: m['companyEmail'],
        phoneNumber: m['phoneNumber'],
        whatsappNumber: m['whatsappNumber'],
        joiningDate: m['joiningDate'],
        reportingManagerEmployeeId: m['reportingManagerEmployeeId'],
        workLocation: m['workLocation'],
        shiftTiming: m['shiftTiming'],
        notes: m['notes'],
      );
}

class EmployeeCompensation {
  final String employeeId;
  final int baseSalaryPaisa;
  final String currency;
  final String compensationType;
  final String? defaultPaymentMethod;
  final String? effectiveFrom;

  EmployeeCompensation({
    required this.employeeId,
    required this.baseSalaryPaisa,
    required this.currency,
    required this.compensationType,
    this.defaultPaymentMethod,
    this.effectiveFrom,
  });

  factory EmployeeCompensation.fromMap(String id, Map<String, dynamic> m) => EmployeeCompensation(
        employeeId: id,
        baseSalaryPaisa: m['baseSalaryPaisa'] ?? 0,
        currency: m['currency'] ?? 'PKR',
        compensationType: m['compensationType'] ?? 'Salary',
        defaultPaymentMethod: m['defaultPaymentMethod'],
        effectiveFrom: m['effectiveFrom'],
      );
}
