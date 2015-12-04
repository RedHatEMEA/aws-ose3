#!/usr/bin/python

import OpenSSL.crypto
import argparse
import base64
import glob
import k8s
import os
import shutil
import yaml


def sn():
    sn = int(open("/etc/origin/master/ca.serial.txt").read())
    open("/etc/origin/master/ca.serial.txt", "w").write("%u" % (sn + 1))
    return sn


def make_cert(fn, o, cn, san, eku):
    ca_cert = OpenSSL.crypto.load_certificate(OpenSSL.crypto.FILETYPE_PEM,
                                              open("/etc/origin/master/ca.crt").read())
    ca_key = OpenSSL.crypto.load_privatekey(OpenSSL.crypto.FILETYPE_PEM,
                                            open("/etc/origin/master/ca.key").read())

    key = OpenSSL.crypto.PKey()
    key.generate_key(OpenSSL.crypto.TYPE_RSA, 2048)

    cert = OpenSSL.crypto.X509()
    cert.set_version(2)
    cert.set_serial_number(sn())
    if o:
        cert.get_subject().O = o
    cert.get_subject().CN = cn
    cert.gmtime_adj_notBefore(-60 * 60)
    cert.gmtime_adj_notAfter((2 * 365 * 24 - 1) * 60 * 60)
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


def do_master_config():
    # update master-config.yaml
    f = "/etc/origin/master/master-config.yaml"
    y = yaml.load(open(f, "r").read())
    y["assetConfig"]["loggingPublicURL"] = "https://kibana." + args.subdomain + "/"
    y["assetConfig"]["masterPublicURL"] = "https://" + args.public_hostname + ":8443"
    y["assetConfig"]["metricsPublicURL"] = "https://hawkular-metrics." + args.subdomain + "/hawkular/metrics"
    y["assetConfig"]["publicURL"] = "https://" + args.public_hostname + ":8443/console/"
    y["corsAllowedOrigins"] = ["127.0.0.1",
                               "localhost",
                               "172.30.0.1",
                               "kubernetes",
                               "kubernetes.default",
                               "kubernetes.default.svc",
                               "kubernetes.default.svc.cluster.local",
                               "openshift",
                               "openshift.default",
                               "openshift.default.svc",
                               "openshift.default.svc.cluster.local",
                               args.private_ip,
                               args.private_hostname,
                               args.public_ip,
                               args.public_hostname
                               ]
    y["etcdClientInfo"]["urls"] = ["https://" + args.private_hostname + ":4001"]
    y["etcdConfig"]["address"] = args.private_hostname + ":4001"
    y["etcdConfig"]["peerAddress"] = args.private_hostname + ":7001"
    y["kubernetesMasterConfig"]["masterIP"] = args.private_ip
    y["masterPublicURL"] = "https://" + args.public_hostname + ":8443"
    y["oauthConfig"]["assetPublicURL"] = "https://" + args.public_hostname + ":8443/console/"
    y["oauthConfig"]["masterPublicURL"] = "https://" + args.public_hostname + ":8443"
    y["oauthConfig"]["masterURL"] = "https://" + args.private_hostname + ":8443"
    y["routingConfig"]["subdomain"] = "apps." + args.subdomain
    open(f, "w").write(yaml.dump(y, default_flow_style=False))

    # rebuild SSL certs
    for cert in ["etcd.server", "master.server"]:
        make_cert("/etc/origin/master/" + cert, None, "172.30.0.1",
                  ", ".join(["DNS:kubernetes",
                             "DNS:kubernetes.default",
                             "DNS:kubernetes.default.svc",
                             "DNS:kubernetes.default.svc.cluster.local",
                             "DNS:openshift",
                             "DNS:openshift.default",
                             "DNS:openshift.default.svc",
                             "DNS:openshift.default.svc.cluster.local",
                             "DNS:" + args.public_hostname,
                             "DNS:" + args.private_hostname,
                             "DNS:172.30.0.1",
                             "DNS:" + args.public_ip,
                             "DNS:" + args.private_ip,
                             "IP:172.30.0.1",
                             "IP:" + args.public_ip,
                             "IP:" + args.private_ip]), "serverAuth")

    # rebuild service kubeconfig files
    ca = base64.b64encode(open("/etc/origin/master/ca.crt").read())
    private_hostname_ = args.private_hostname.replace(".", "-")
    public_hostname_ = args.public_hostname.replace(".", "-")
    for kc in ["admin", "openshift-master", "openshift-registry", "openshift-router"]:
        y = {"apiVersion": "v1",
             "kind": "Config",
             "preferences": {},
             "clusters": [{"name": public_hostname_ + ":8443",
                           "cluster": {"certificate-authority-data": ca,
                                       "server": "https://" + args.public_hostname + ":8443"}},
                          {"name": private_hostname_ + ":8443",
                           "cluster": {"certificate-authority-data": ca,
                                       "server": "https://" + args.private_hostname + ":8443"}}],
             "users": [{"name": "system:" + kc + "/" + private_hostname_ + ":8443",
                        "user": {"client-certificate-data": base64.b64encode(open("/etc/origin/master/" + kc + ".crt").read()),
                                 "client-key-data": base64.b64encode(open("/etc/origin/master/" + kc + ".key").read())}}],
             "contexts": [{"name": "default/" + public_hostname_ + ":8443/system:" + kc,
                           "context": {"cluster": public_hostname_ + ":8443",
                                       "namespace": "default",
                                       "user": "system:" + kc + "/" + private_hostname_ + ":8443"}},
                          {"name": "default/" + private_hostname_ + ":8443/system:" + kc,
                           "context": {"cluster": private_hostname_ + ":8443",
                                       "namespace": "default",
                                       "user": "system:" + kc + "/" + private_hostname_ + ":8443"}}],
             "current-context": "default/" + private_hostname_ + ":8443/system:" + kc}

        open("/etc/origin/master/" + kc + ".kubeconfig", "w").write(yaml.dump(y, default_flow_style=False))

    # rebuild root's kubeconfig file
    shutil.copy("/etc/origin/master/admin.kubeconfig", "/root/.kube/config")


def do_node_config():
    # update node-config.yaml
    f = "/etc/origin/node/node-config.yaml"
    y = yaml.load(open(f, "r").read())
    y["masterKubeConfig"] = "system:node:" + args.private_hostname + ".kubeconfig"
    y["nodeIP"] = args.private_ip
    y["nodeName"] = args.private_hostname
    open(f, "w").write(yaml.dump(y, default_flow_style=False))

    # remove old node SSL certs and kubeconfig files
    for f in glob.glob("/etc/origin/node/system:node:*"):
        os.unlink(f)

    # rebuild node SSL certs
    make_cert("/etc/origin/node/server", None, "172.30.0.1",
              ", ".join(["DNS:kubernetes",
                         "DNS:kubernetes.default",
                         "DNS:kubernetes.default.svc",
                         "DNS:kubernetes.default.svc.cluster.local",
                         "DNS:openshift",
                         "DNS:openshift.default",
                         "DNS:openshift.default.svc",
                         "DNS:openshift.default.svc.cluster.local",
                         "DNS:" + args.public_hostname,
                         "DNS:" + args.private_hostname,
                         "DNS:172.30.0.1",
                         "DNS:" + args.public_ip,
                         "DNS:" + args.private_ip,
                         "IP:172.30.0.1",
                         "IP:" + args.public_ip,
                         "IP:" + args.private_ip]), "serverAuth")

    make_cert("/etc/origin/node/system:node:" + args.private_hostname, "system:nodes", "system:node:" + args.private_hostname, None, "clientAuth")

    # rebuild node kubeconfig file
    private_hostname_ = args.private_hostname.replace(".", "-")
    y = {"apiVersion": "v1",
         "kind": "Config",
         "preferences": {},
         "clusters": [{"name": private_hostname_ + ":8443",
                       "cluster": {"certificate-authority-data": base64.b64encode(open("/etc/origin/node/ca.crt").read()),
                                   "server": "https://" + args.private_hostname + ":8443"}}],
         "users": [{"name": "system:node:" + args.private_hostname + "/" + private_hostname_ + ":8443",
                    "user": {"client-certificate-data": base64.b64encode(open("/etc/origin/node/system:node:" + args.private_hostname + ".crt").read()),
                             "client-key-data": base64.b64encode(open("/etc/origin/node/system:node:" + args.private_hostname + ".key").read())}}],
         "contexts": [{"name": "default/" + private_hostname_ + ":8443/system:node:" + args.private_hostname,
                       "context": {"cluster": private_hostname_ + ":8443",
                                   "namespace": "default",
                                   "user": "system:node:" + args.private_hostname + "/" + private_hostname_ + ":8443"}}],
         "current-context": "default/" + private_hostname_ + ":8443/system:node:" + args.private_hostname}

    open("/etc/origin/node/system:node:" + args.private_hostname + ".kubeconfig", "w").write(yaml.dump(y, default_flow_style=False))


def do_restart_services():
    svcs = ["atomic-openshift-master", "atomic-openshift-node"]
    for svc in svcs[::-1]:
        os.system("systemctl stop " + svc)

    # clear out finished Docker containers
    os.system("docker ps -aq | xargs docker rm -f")

    # trigger complete reconfiguration of OVS
    os.unlink("/run/openshift-sdn/docker-network")
    os.system("ovs-ofctl -O OpenFlow13 del-flows br0")

    for svc in svcs:
        os.system("systemctl start " + svc)


def do_cleanup(api):
    for i in api.get("/api/v1/nodes")._items:
        if i.metadata.name != args.private_hostname:
            api.delete(i.metadata.selfLink)

    for i in api.get("/oapi/v1/hostsubnets")._items:
        if i.metadata.name != args.private_hostname:
            api.delete(i.metadata.selfLink)

    for i in api.get("/oapi/v1/oauthclients")._items:
        i.redirectURIs = [uri for uri in i.redirectURIs if not ("8443" in uri and args.public_hostname not in uri)]
        api.put(i.metadata.selfLink, i)

    for i in api.get("/api/v1/events")._items:
        api.delete(i.metadata.selfLink)

    for i in api.get("/api/v1/pods")._items:
        api.delete(i.metadata.selfLink)


def do_services_config_post(api):
    # replace DCs (we replace so that latestVersion is reset)
    dc = api.get("/oapi/v1/namespaces/default/deploymentconfigs/docker-registry")
    delete_dc(api, dc)

    set_env(dc.spec.template.spec.containers[0], "OPENSHIFT_MASTER", "https://" + args.public_hostname + ":8443")
    dc.metadata = {k: dc.metadata[k] for k in dc.metadata if k in ["labels", "name"]}
    del dc.status
    api.post("/oapi/v1/namespaces/default/deploymentconfigs", dc)

    dc = api.get("/oapi/v1/namespaces/default/deploymentconfigs/router")
    delete_dc(api, dc)

    set_env(dc.spec.template.spec.containers[0], "OPENSHIFT_MASTER", "https://" + args.public_hostname + ":8443")
    dc.metadata = {k: dc.metadata[k] for k in dc.metadata if k in ["labels", "name"]}
    del dc.status
    api.post("/oapi/v1/namespaces/default/deploymentconfigs", dc)


def do_kibana_config_pre(api):
    # rebuild SSL cert
    make_cert("kibana", None, "kibana",
              ", ".join(["DNS:kibana",
                         "DNS:kibana." + args.subdomain,
                         "DNS:kibana-ops." + args.subdomain]), "serverAuth")

    sec = api.get("/api/v1/namespaces/logging/secrets/logging-kibana-proxy")
    sec.data["server-cert"] = base64.b64encode(open("kibana.crt").read())
    sec.data["server-key"] = base64.b64encode(open("kibana.key").read())
    api.put(sec.metadata.selfLink, sec)


def do_kibana_config_post(api):
    # replace logging-kibana DC (we replace so that latestVersion is reset)
    dc = api.get("/oapi/v1/namespaces/logging/deploymentconfigs/logging-kibana")
    delete_dc(api, dc)

    set_env(dc.spec.template.spec.containers[1], "OAP_PUBLIC_MASTER_URL", "https://" + args.public_hostname + ":8443")
    dc.metadata = {k: dc.metadata[k] for k in dc.metadata if k in ["labels", "name"]}
    del dc.status
    api.post("/oapi/v1/namespaces/logging/deploymentconfigs", dc)

    # fix route hostnames
    r = api.get("/oapi/v1/namespaces/logging/routes/kibana")
    r.spec.host = "kibana." + args.subdomain
    api.put(r.metadata.selfLink, r)

    r = api.get("/oapi/v1/namespaces/logging/routes/kibana-ops")
    r.spec.host = "kibana-ops." + args.subdomain
    api.put(r.metadata.selfLink, r)


def do_hawkular_config_pre(api):
    # rebuild SSL cert
    make_cert("hawkular-metrics", None, "hawkular-metrics",
              ", ".join(["DNS:hawkular-metrics",
                         "DNS:hawkular-metrics." + args.subdomain]), "serverAuth")

    open("hawkular-metrics.crt", "a").write(open("/etc/origin/master/ca.crt").read())

    # key and cert go into hawkular-metrics-secrets keystore
    sec = api.get("/api/v1/namespaces/openshift-infra/secrets/hawkular-metrics-secrets")
    pw = sec.data["hawkular-metrics.keystore.password"].decode("base64").strip()
    os.system("openssl pkcs12 -export -in hawkular-metrics.crt -inkey hawkular-metrics.key -out hawkular-metrics.pkcs12 -name hawkular-metrics -password pass:" + pw)
    os.system("keytool -importkeystore -srckeystore hawkular-metrics.pkcs12 -srcstoretype pkcs12 -destkeystore keystore -deststorepass " + pw + " -srcstorepass " + pw)
    sec.data["hawkular-metrics.keystore"] = base64.b64encode(open("keystore").read())
    api.put(sec.metadata.selfLink, sec)

    # cert goes into hawkular-metrics-certificate
    sec = api.get("/api/v1/namespaces/openshift-infra/secrets/hawkular-metrics-certificate")
    os.system("openssl x509 -in hawkular-metrics.crt -out hawkular-metrics.crt.der -outform der")
    sec.data["hawkular-metrics.certificate"] = base64.b64encode(open("hawkular-metrics.crt.der").read())
    api.put(sec.metadata.selfLink, sec)

    # cert also goes into hawkular-cassandra-secrets truststore
    sec = api.get("/api/v1/namespaces/openshift-infra/secrets/hawkular-cassandra-secrets")
    pw = sec.data["cassandra.truststore.password"].decode("base64").strip()
    open("truststore", "w").write(sec.data["cassandra.truststore"].decode("base64"))
    os.system("keytool -delete -alias hawkular-metrics -keystore truststore -storepass " + pw)
    os.system("keytool -import -trustcacerts -alias hawkular-metrics -file hawkular-metrics.crt.der -keystore truststore -storepass " + pw)
    sec.data["cassandra.truststore"] = base64.b64encode(open("truststore").read())
    api.put(sec.metadata.selfLink, sec)


def do_hawkular_config_post(api):
    # fix route hostname
    r = api.get("/oapi/v1/namespaces/openshift-infra/routes/hawkular-metrics")
    r.spec.host = "hawkular-metrics." + args.subdomain
    api.put(r.metadata.selfLink, r)


def connect_api():
    return k8s.API("https://" + args.private_hostname + ":8443",
                   ("/etc/origin/master/openshift-master.crt",
                    "/etc/origin/master/openshift-master.key"))


def delete_dc(api, dc):
    # delete DC and cascade to appropriate RCs
    api.delete(dc.metadata.selfLink)

    for rc in api.get("/api/v1/namespaces/" + dc.metadata.namespace + "/replicationcontrollers")._items:
        if rc.metadata.name.startswith(dc.metadata.name + "-"):
            delete_rc(api, rc)


def delete_rc(api, rc):
    # delete RC and cascade to appropriate pods
    api.delete(rc.metadata.selfLink)

    for pod in api.get("/api/v1/namespaces/" + rc.metadata.namespace + "/pods")._items:
        if pod.metadata.name.startswith(rc.metadata.name + "-"):
            api.delete(pod.metadata.selfLink)


def set_env(c, k, v):
    c.env = [e for e in c.env if e.name != k]
    c.env.append(k8s.AttrDict({"name": k, "value": v}))


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("private_hostname")
    ap.add_argument("public_hostname")
    ap.add_argument("private_ip")
    ap.add_argument("public_ip")
    ap.add_argument("subdomain")

    return ap.parse_args()


def main():
    # 1. Update daemon configs and certs
    do_master_config()
    do_node_config()
    do_restart_services()

    api = connect_api()

    # 2. Make necessary changes via API before bulk object delete
    do_kibana_config_pre(api)
    do_hawkular_config_pre(api)

    # 3. Bulk opject delete
    do_cleanup(api)

    # 4. Post bulk object delete changes
    do_services_config_post(api)
    do_kibana_config_post(api)
    do_hawkular_config_post(api)


if __name__ == "__main__":
    args = parse_args()
    main()
