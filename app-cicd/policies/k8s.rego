package main

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg = sprintf("%s uses the disallowed latest tag", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits
  msg = sprintf("%s is missing resource limits", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.requests
  msg = sprintf("%s is missing resource requests", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.runAsNonRoot
  msg = sprintf("%s must run as non-root", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg = sprintf("%s must not run privileged", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.hostNetwork == true
  msg = "hostNetwork is not allowed"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.hostPID == true
  msg = "hostPID is not allowed"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.template.spec.hostIPC == true
  msg = "hostIPC is not allowed"
}

deny[msg] {
  input.kind == "Deployment"
  volume := input.spec.template.spec.volumes[_]
  volume.hostPath
  msg = sprintf("hostPath volumes are not allowed: %s", [volume.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not startswith(container.image, "public.ecr.aws/")
  not contains(container.image, ".dkr.ecr.")
  msg = sprintf("%s image must be from ECR (public.ecr.aws or private ECR registry)", [container.name])
}

deny[msg] {
  input.kind == "Deployment"
  not input.metadata.labels["app.kubernetes.io/name"]
  msg = "Deployment must have app.kubernetes.io/name label"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.replicas > 10
  msg = sprintf("Deployment replica count (%d) exceeds maximum allowed (10)", [input.spec.replicas])
}
