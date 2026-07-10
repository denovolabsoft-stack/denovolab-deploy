# DeNoVoLab Class4 Fusion Deploy

Provider-native install assets for the public one-click installer.

## Targets

- `aws/` - CloudFormation quick-create template for AWS.
- `gcp/` - Terraform and Cloud Shell tutorial for Google Cloud.
- `own-server/` - Root-shell installer for a customer-managed Rocky Linux 8 server.

Keep this repository public when using GitHub-backed one-click links. AWS
CloudFormation templates are still hosted from S3 for the AWS console button,
while Google Cloud Shell and own-server installs can read directly from GitHub.
