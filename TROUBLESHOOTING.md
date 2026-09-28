# Troubleshooting Practice

Three broken Deployment manifests live in [k8s/](k8s/): `broken-1.yaml`,
`broken-2.yaml`, `broken-3.yaml`. Each has exactly one bug. Apply one at a
time, then work through its section below top to bottom — try the
diagnostic commands and form a hypothesis **before** scrolling past the
"Stop here and investigate" line.

General workflow for any broken pod:

```bash
kubectl apply -f k8s/broken-1.yaml
kubectl get pods -l app=app-broken-1 -w
```

Watch it for 20-30 seconds, then Ctrl-C and start digging.

---

## broken-1.yaml — Symptom: pod never goes Ready

Apply it and watch `kubectl get pods -l app=app-broken-1`. The pod sits in
a non-Running state and never becomes Ready.

**Diagnostic commands to run yourself:**

```bash
kubectl get pods -l app=app-broken-1
kubectl describe pod -l app=app-broken-1
kubectl get events --sort-by=.lastTimestamp | tail -20
```

Look specifically at the pod's `STATUS` column, and the `Events` section
at the bottom of `describe pod`.

**Stop here and investigate before reading on.**

<details>
<summary>What the output shows / root cause / fix</summary>

`kubectl get pods` shows `STATUS: ImagePullBackOff` (or `ErrImagePull`
right after creation, which backs off into `ImagePullBackOff`).

`kubectl describe pod` events show something like:

```
Failed to pull image "k8s-learning-app:v1-typo": ...
Error: ErrImagePull
Back-off pulling image "k8s-learning-app:v1-typo"
```

**Root cause:** the Deployment references `k8s-learning-app:v1-typo`, a
tag that was never built or imported — only `k8s-learning-app:v1` exists
in k3s's containerd image store. Since `imagePullPolicy: Never` is set,
the kubelet won't even try to reach a registry; it just fails to find the
image locally.

**Fix:** correct the image tag back to `k8s-learning-app:v1` (or build and
import an image actually tagged `v1-typo`). Verify available local images
with `sudo k3s ctr images list`.

```bash
kubectl set image deployment/app-broken-1 k8s-learning-app=k8s-learning-app:v1
kubectl rollout status deployment/app-broken-1
```

</details>

---

## broken-2.yaml — Symptom: pod keeps restarting

Apply it and watch `kubectl get pods -l app=app-broken-2 -w` for about a
minute. `RESTARTS` climbs steadily.

**Diagnostic commands to run yourself:**

```bash
kubectl get pods -l app=app-broken-2
kubectl describe pod -l app=app-broken-2
kubectl logs -l app=app-broken-2 --previous
```

Pay attention to the `Liveness`/`Readiness` lines near the top of
`describe pod`, and the `Events` section (look for `Killing` and
`Unhealthy`).

**Stop here and investigate before reading on.**

<details>
<summary>What the output shows / root cause / fix</summary>

`kubectl get pods` shows a climbing `RESTARTS` count, with `STATUS`
cycling through `Running` → `CrashLoopBackOff` (or oscillating between
`Running` and back).

`kubectl describe pod` shows in `Events`:

```
Warning  Unhealthy  ...  Liveness probe failed: Get "http://<pod-ip>:9999/health": dial tcp <pod-ip>:9999: connect: connection refused
Normal   Killing    ...  Container k8s-learning-app failed liveness probe, will be restarted
```

`kubectl logs --previous` shows a perfectly normal, healthy application
that was running fine right up until it got killed — no application error
at all.

**Root cause:** the app only listens on port 8080 (see the Dockerfile's
`EXPOSE 8080` and the `uvicorn --port 8080` command), but the liveness
probe in this manifest points at port `9999`. The probe can never
succeed, so the kubelet repeatedly decides the container is unhealthy and
restarts it — even though the app itself is fine.

**Fix:** point the liveness probe at port 8080 to match the container's
actual listening port and the readiness probe.

```bash
kubectl apply -f k8s/deployment.yaml   # or edit broken-2.yaml's port back to 8080
```

</details>

---

## broken-3.yaml — Symptom: pod stuck, never even starts the container

Apply it and check `kubectl get pods -l app=app-broken-3`. Unlike the
other two, this pod never even gets to `Running` once — no restarts, no
image pull attempt.

**Diagnostic commands to run yourself:**

```bash
kubectl get pods -l app=app-broken-3
kubectl describe pod -l app=app-broken-3
kubectl get configmap app-config -o yaml
```

Compare the keys in the ConfigMap against what the Deployment's `env`
section asks for.

**Stop here and investigate before reading on.**

<details>
<summary>What the output shows / root cause / fix</summary>

`kubectl get pods` shows `STATUS: CreateContainerConfigError`.

`kubectl describe pod` events show:

```
Warning  Failed  ...  Error: couldn't find key APP_MSG_TYPO in ConfigMap default/app-config
```

`kubectl get configmap app-config -o yaml` shows the ConfigMap only has
`APP_MESSAGE` and `APP_ENV` under `data` — there is no `APP_MSG_TYPO` key.

**Root cause:** the Deployment uses `env.valueFrom.configMapKeyRef` with
`key: APP_MSG_TYPO`, which doesn't exist in the `app-config` ConfigMap.
Kubernetes can't assemble the container's environment, so it never even
attempts to start the container — this fails before the image pull or
probes are ever relevant.

**Fix:** correct the key to `APP_MESSAGE` (or add an `APP_MSG_TYPO` key to
the ConfigMap, though that's not what the app reads).

```bash
kubectl apply -f k8s/deployment.yaml   # or edit broken-3.yaml's key back to APP_MESSAGE
```

</details>

---

## Cleaning up the broken variants

```bash
kubectl delete -f k8s/broken-1.yaml
kubectl delete -f k8s/broken-2.yaml
kubectl delete -f k8s/broken-3.yaml
```
