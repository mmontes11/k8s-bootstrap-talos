# k8s-bootstrap-rpi-talos
🚀 Kubernetes cluster bootstrapping for Raspberry Pi using [Talos](https://www.talos.dev/).

### Node preparation

- [Update the EEPROM](https://www.talos.dev/v1.7/talos-guides/install/single-board-computers/rpi_generic/#updating-the-eeprom)
- Get an image ID at [factory.talos.dev](https://factory.talos.dev/)
- Download the image
```bash
IMAGE_ID=<image-id> make image
```
- Write the image
```bash
sudo dd if=metal-arm64.raw of=/dev/mmcblk0 conv=fsync bs=4M
```
- Boot and assign a static IP in the router based on the [MAC](https://kubito.dev/posts/getting-pi-mac-address/)


### Controlplane

- Generate secrets
```bash
make gen-secrets
```
- Generate configuration
```bash
make gen-config
```
- Apply controlplane configuration
```bash
NODE=<controlplane-ip> make apply-controlplane
```
- Bootstrap Kubernetes
```bash
NODE=<controlplane-ip> make bootstrap-k8s
```

### Worker

- Generate worker config
```bash
WORKER=<worker-name> make gen-worker
```
- Apply worker configuration
```bash
WORKER=<worker-name> NODE=<worker-ip> make apply-worker
```

### Configuration

- Get kubeconfig
```bash
NODE=<controlplane-ip> make kubeconfig
```
- Get talosconfig
```bash
make talosconfig
```

### Reference
- [Talos docs](https://www.talos.dev/v1.7/)
- [Talos Linux Setup](https://kubito.dev/series/talos-linux-setup/) by [@kubito](https://kubito.dev/)