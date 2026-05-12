# AWS Final Project - Terraform Infrastructure

## Descripción

Infraestructura completa para desplegar una aplicación PHP segura, escalable y altamente disponible en AWS. Incluye VPC, ALB, Auto Scaling Group, RDS MySQL y gestión de credenciales con Secrets Manager.

## Prerrequisitos

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configurado con credenciales del Learner Lab
- Sesión activa en AWS Academy Learner Lab (botón "Start Lab" verde)

## Estructura de Archivos

```
terraform/
├── providers.tf          # Provider AWS (us-east-1)
├── variables.tf          # Variables configurables
├── network.tf            # VPC, subnets, IGW, NAT, route tables
├── security_groups.tf    # Security groups (ALB, EC2, RDS)
├── iam.tf                # IAM role, policies, instance profile
├── rds.tf                # RDS MySQL + Secrets Manager
├── alb.tf                # ALB, target group, listener
├── autoscaling.tf        # Launch template, ASG, scaling policy
├── userdata.sh.tpl       # Script de bootstrap para EC2
├── outputs.tf            # Outputs (ALB DNS, RDS endpoint)
└── README.md             # Este archivo
```

## Despliegue Paso a Paso

### 1. Verificar identidad AWS

```bash
aws sts get-caller-identity
```

Debe mostrar la cuenta del Learner Lab.

### 2. Inicializar Terraform

```bash
cd aws-final-project/terraform
terraform init
```

### 3. Revisar el plan

```bash
terraform plan
```

Revisa que se crearán ~25 recursos (VPC, subnets, SGs, IAM, RDS, ALB, ASG, etc.)

### 4. Aplicar la infraestructura

```bash
terraform apply
```

Confirma con `yes`. El despliegue toma ~10-15 minutos (RDS es lo más lento).

### 5. Obtener la URL del ALB

```bash
terraform output alb_dns_name
```

### 6. Importar datos SQL (paso manual)

Espera ~5 minutos después del `apply` para que las EC2 terminen su bootstrap.

```bash
# Obtener el ID de una instancia
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=final-project-app-instance" \
             "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

# Conectar vía SSM
aws ssm start-session --target $INSTANCE_ID
```

Dentro de la sesión SSM:

```bash
bash
wget -q https://aws-tc-largeobjects.s3.us-west-2.amazonaws.com/CUR-TF-200-ACACAD-3-113230/22-lab-Capstone-project/s3/Countrydatadump.sql
SECRET_ARN=$(aws secretsmanager list-secrets --filters Key=name,Values=rds! --query "SecretList[0].ARN" --output text)
SECRET=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text)
USER=$(echo $SECRET | python3 -c "import json,sys; print(json.load(sys.stdin)['username'])")
PWD=$(echo $SECRET | python3 -c "import json,sys; print(json.load(sys.stdin)['password'])")
RDS_HOST=$(aws rds describe-db-instances --query "DBInstances[0].Endpoint.Address" --output text)
mysql -h $RDS_HOST -u $USER -p$PWD countries < Countrydatadump.sql
mysql -h $RDS_HOST -u $USER -p$PWD countries -e "SELECT COUNT(*) FROM countrydata_final;"
```

Debe retornar **214** filas.

### 7. Probar la aplicación

```bash
# Obtener URL
ALB_DNS=$(terraform output -raw alb_dns_name)

# Verificar que responde
curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS
# Esperado: 200 o 302
```

Abre en el navegador: `http://<ALB_DNS>`

Prueba las 5 queries:
1. Mobile Phones ✓
2. Population ✓
3. Life Expectancy ✓ (bug fix aplicado)
4. GDP ✓
5. Childhood Mortality ✓

## Validaciones de Seguridad

```bash
# Verificar que EC2 no tiene IP pública
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=final-project-app-instance" \
  --query "Reservations[].Instances[].PublicIpAddress"
# Esperado: [null, null]

# Verificar que RDS no es público
aws rds describe-db-instances \
  --query "DBInstances[0].PubliclyAccessible"
# Esperado: false

# Verificar security groups (no port 22)
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=final-project-ec2-sg" \
  --query "SecurityGroups[0].IpPermissions[].FromPort"
# Esperado: [80] (solo puerto 80)
```

## Limpieza

```bash
terraform destroy
```

Confirma con `yes`. Esto elimina TODOS los recursos creados.

## Restricciones del Lab

- Región: us-east-1 únicamente
- Instancias: t2.micro (EC2), db.t3.micro (RDS)
- Sin HTTPS ni dominio personalizado
- Sin autenticación de usuarios (fuera del alcance del POC)
- Presupuesto limitado - destruir recursos cuando no se usen
- Solo una instancia RDS en la cuenta

## Variables Configurables

| Variable | Default | Descripción |
|---|---|---|
| `project_prefix` | `final-project` | Prefijo para nombres de recursos |
| `aws_region` | `us-east-1` | Región AWS |
| `vpc_cidr` | `10.0.0.0/16` | CIDR del VPC |
| `instance_type` | `t2.micro` | Tipo de instancia EC2 |
| `db_instance_class` | `db.t3.micro` | Clase de instancia RDS |
| `db_name` | `countries` | Nombre de la base de datos |
| `asg_min` | `2` | Mínimo de instancias |
| `asg_max` | `4` | Máximo de instancias |
| `asg_desired` | `2` | Instancias deseadas |
| `cpu_target` | `50` | % CPU objetivo para escalado |
