/// Largest payment proof the server accepts.
const int depositProofMaxBytes = 2 * 1024 * 1024;

const Set<String> _allowedProofExtensions = <String>{'jpg', 'jpeg', 'png'};

/// True when a payment proof may be uploaded: a JPG or PNG of at most 2 MB
/// that is not empty.
bool isValidDepositProof({required String fileName, required int sizeBytes}) {
  if (sizeBytes <= 0 || sizeBytes > depositProofMaxBytes) return false;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return false;
  return _allowedProofExtensions.contains(
    fileName.substring(dot + 1).toLowerCase(),
  );
}
