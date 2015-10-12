#!/usr/bin/python

import OpenSSL.crypto
import os
import shutil
import sys


def sn():
    try:
        sn = int(open("/etc/openshift/master/ca.serial.txt").read())
    except IOError:
        sn = 1

    open("/etc/openshift/master/ca.serial.txt", "w").write("%u" % (sn + 1))
    return sn


def make_cert(fn, o, cn, san, eku):
    ca_cert = OpenSSL.crypto.load_certificate(OpenSSL.crypto.FILETYPE_PEM,
                                              open("/etc/openshift/master/ca.crt").read())
    ca_key = OpenSSL.crypto.load_privatekey(OpenSSL.crypto.FILETYPE_PEM,
                                            open("/etc/openshift/master/ca.key").read())

    key = OpenSSL.crypto.PKey()
    key.generate_key(OpenSSL.crypto.TYPE_RSA, 2048)

    cert = OpenSSL.crypto.X509()
    cert.set_version(2)
    cert.set_serial_number(sn())
    if o:
        cert.get_subject().O = o
    cert.get_subject().CN = cn
    cert.gmtime_adj_notBefore(-60 * 60)
    cert.gmtime_adj_notAfter((365 * 24 - 1) * 60 * 60)
    cert.set_issuer(ca_cert.get_subject())
    cert.set_pubkey(key)
    cert.add_extensions([
        OpenSSL.crypto.X509Extension("keyUsage", True, "digitalSignature, keyEncipherment"),
        OpenSSL.crypto.X509Extension("extendedKeyUsage", False, eku),
        OpenSSL.crypto.X509Extension("basicConstraints", True, "CA:FALSE")
    ])
    if san:
        cert.add_extensions([
            OpenSSL.crypto.X509Extension("subjectAltName", False, san)
        ])
    cert.sign(ca_key, "sha256")

    with os.fdopen(os.open("%s.key" % fn, os.O_WRONLY | os.O_CREAT, 0600),
                           "w") as f:
        f.write(OpenSSL.crypto.dump_privatekey(OpenSSL.crypto.FILETYPE_PEM,
                                               key))
    with open("%s.crt" % fn, "w") as f:
        f.write(OpenSSL.crypto.dump_certificate(OpenSSL.crypto.FILETYPE_PEM,
                                                cert))

if __name__ == "__main__":
    make_cert("/etc/openshift/master/etcd.server", None, sys.argv[1], "DNS:" + sys.argv[1], "serverAuth")
    make_cert("/etc/openshift/master/master.server", None, sys.argv[1], "DNS:" + sys.argv[1], "serverAuth")
    make_cert("/etc/openshift/node/server", None, sys.argv[1], "DNS:" + sys.argv[1], "serverAuth")
    make_cert("/etc/openshift/node/system:node:" + sys.argv[1], "system:nodes", sys.argv[1], None, "clientAuth")
