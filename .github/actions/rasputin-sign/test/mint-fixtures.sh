#!/usr/bin/env bash
# Mint a throwaway PKI for exercising the rasputin-sign action.
#
# It reproduces, with the same openssl invocations, what
# rasputin-control-plane scripts/pki-init.sh mints: an EC P-384 root, an EC
# P-384 intermediate, and leaves carrying the extensions pki-init sets. It also
# mints the leaves pki-init REFUSES to hand over, so the preflight can be shown
# to reject them rather than only shown to accept a good one.
#
# Nothing here is a Rasputin credential: the root is generated on the spot and
# discarded with the working directory. Usage: mint-fixtures.sh <out-dir>

set -euo pipefail

OUT=${1:?usage: mint-fixtures.sh <out-dir>}
mkdir -p "$OUT"
cd "$OUT"

EC_CURVE=secp384r1
LEAF_DAYS=730
OID_RELEASE=1.3.6.1.4.1.66587.1.1.1
OID_CATALOG=1.3.6.1.4.1.66587.1.1.2

openssl ecparam -genkey -name "$EC_CURVE" -noout -out root-ca.key
openssl req -x509 -new -key root-ca.key -out root-ca.pem -days 7300 -sha384 \
  -subj "/CN=Rasputin Test Root CA" \
  -extensions v3_ca -config <(cat <<'EOF'
[req]
distinguished_name = dn
[dn]
[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
EOF
)

openssl ecparam -genkey -name "$EC_CURVE" -noout -out intermediate-ca.key
openssl req -new -key intermediate-ca.key -out intermediate-ca.csr \
  -subj "/CN=Rasputin Test Update Signing CA"
openssl x509 -req -in intermediate-ca.csr \
  -CA root-ca.pem -CAkey root-ca.key -CAcreateserial \
  -out intermediate-ca.pem -days 3650 -sha384 \
  -extfile <(cat <<'EOF'
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
EOF
)
rm -f intermediate-ca.csr

# mint <name> <keyUsage> <extendedKeyUsage>
mint() {
  local name=$1 ku=$2 eku=$3
  openssl ecparam -genkey -name "$EC_CURVE" -noout -out "${name}.key"
  openssl req -new -key "${name}.key" -out "${name}.csr" -subj "/CN=Rasputin Test ${name}"
  openssl x509 -req -in "${name}.csr" \
    -CA intermediate-ca.pem -CAkey intermediate-ca.key -CAcreateserial \
    -out "${name}.pem" -days "$LEAF_DAYS" -sha384 \
    -extfile <(printf "keyUsage=critical,%s\nextendedKeyUsage=critical,%s" "$ku" "$eku")
  rm -f "${name}.csr"
  cat "${name}.pem" intermediate-ca.pem > "${name}-chain.pem"
}

# What pki-init.sh --rotate-leaf issues today: the release OID, generic
# codeSigning (transitional, for agents predating the EKU check) and
# emailProtection (the S/MIME purpose every deployed board enforces).
mint release-good  digitalSignature "codeSigning,emailProtection,${OID_RELEASE}"

# leaf-002, the one that shipped: a perfect chain, codeSigning + the release
# OID, and no emailProtection. It killed rasputin-os release run #171 in
# `rauc bundle` with "unsuitable certificate purpose".
mint release-no-email digitalSignature "codeSigning,${OID_RELEASE}"

# The reverse gap: satisfies the S/MIME default, but a board with
# check-purpose=codesign refuses it.
mint release-no-codesign digitalSignature "emailProtection,${OID_RELEASE}"

# Every X509 purpose satisfied, no Rasputin purpose OID — artifactsig refuses it.
mint release-no-oid digitalSignature "codeSigning,emailProtection"

# A leaf carrying 1.3.6.1.4.1.66587.1.1.11 and NOT ...1.1.1. The release OID is
# a textual prefix of it, so a substring test accepts this leaf for the release
# purpose (geekdojo/geekdojo-brain#474). Nothing has minted ...1.1.11 yet, which
# is exactly why a gate must not accept it in advance.
mint release-longer-arc digitalSignature "codeSigning,emailProtection,${OID_RELEASE}1"

# What pki-init.sh --catalog-leaf issues: the catalog OID and nothing else.
mint catalog-good digitalSignature "${OID_CATALOG}"

# A catalog leaf that quietly acquired codeSigning re-merges the blast radii
# the catalog/release split exists to keep apart.
mint catalog-codesigning digitalSignature "codeSigning,${OID_CATALOG}"

# A leaf-only secret: splits without complaint, leaves an empty intermediate,
# and ships a signature no device holding only the root can chain.
cp release-good.pem release-leafonly-chain.pem
cp release-good.key release-leafonly.key

chmod 600 ./*.key
echo "fixtures minted in $OUT"
