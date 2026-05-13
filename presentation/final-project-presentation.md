# Proyecto Final - Arquitectura en la Nube

## 1. Portada

**Proyecto Final: Aplicación PHP segura y escalable en AWS**  
Equipo 5: Jesús Flores, Samuel, Santiago  
AWS Academy Learner Lab  
Mayo 2026

## 2. Escenario

Una organización ficticia sin fines de lucro ofrece un sitio web para que investigadores consulten estadísticas de desarrollo global por país.

El sitio original creció en tráfico, se volvió lento y sufrió un intento de ataque de ransomware. La solución propuesta migra la aplicación a AWS con una arquitectura más segura, escalable y disponible.

## 3. Objetivos Del Proyecto

- Desplegar una aplicación PHP funcional en AWS.
- Separar la capa web de la base de datos.
- Usar Amazon RDS MySQL para almacenar datos.
- Usar AWS Secrets Manager para credenciales.
- Distribuir tráfico con Application Load Balancer.
- Ejecutar EC2 privadas con Auto Scaling Group.
- Acceder administrativamente mediante SSM Session Manager.
- Importar el dump SQL con 214 países.

## 4. Arquitectura General

La solución implementa una arquitectura de tres capas:

- Capa pública: Internet Gateway, NAT Gateway y Application Load Balancer.
- Capa privada de aplicación: EC2 con Apache y PHP en Auto Scaling Group.
- Capa privada de datos: Amazon RDS MySQL con la base `countries`.

## 5. Infraestructura Implementada

- VPC `10.0.0.0/16`.
- 2 subredes públicas en `us-east-1a` y `us-east-1b`.
- 2 subredes privadas para aplicación.
- 2 subredes privadas para base de datos.
- ALB público en HTTP puerto 80.
- ASG con `desired = 2`, `min = 2`, `max = 4`.
- Launch Template con Amazon Linux 2023 y `t2.micro`.
- RDS MySQL `db.t3.micro`.

## 6. Despliegue Con Terraform

El despliegue se ejecutó desde `aws-final-project/terraform`.

Comandos principales:

```powershell
aws sts get-caller-identity
terraform init
terraform validate
terraform plan
terraform apply
```

El primer intento falló por permisos IAM de AWS Academy. Se corrigió usando `LabInstanceProfile` en vez de crear un rol nuevo.

## 7. Seguridad

- EC2 no tienen IP pública.
- RDS no es público.
- Security Group del ALB permite HTTP desde internet.
- Security Group de EC2 solo permite HTTP desde el ALB.
- Security Group de RDS solo permite MySQL desde EC2.
- Acceso administrativo por SSM, sin SSH.
- Credenciales de RDS gestionadas por Secrets Manager.

## 8. Escalabilidad Y Alta Disponibilidad

- ALB distribuye tráfico hacia instancias EC2 privadas.
- Auto Scaling Group mantiene 2 instancias activas.
- Las instancias están distribuidas en 2 Availability Zones.
- Política de escalado target tracking por CPU al 50%.
- Subredes DB preparadas en 2 Availability Zones.

## 9. Automatización De La Aplicación

El `user-data` del Launch Template:

- Instala Apache, PHP, MariaDB client y SSM agent.
- Inicia y habilita `amazon-ssm-agent`.
- Descarga `Example.zip`.
- Despliega la app en `/var/www/html`.
- Corrige el bug de `lifeexpectancy.php`.
- Importa el dump SQL si aún no hay 214 filas.

## 10. Validaciones

- ALB responde `HTTP 200`.
- App PHP carga correctamente.
- `/query.php` responde `HTTP 200`.
- Target Group tiene 2 instancias `healthy`.
- SSM muestra 2 instancias `Online`.
- RDS `PubliclyAccessible = False`.
- EC2 sin IP pública.
- `countrydata_final` tiene 214 filas.

URL de demo:

`http://final-project-alb-1091345755.us-east-1.elb.amazonaws.com`

## 11. Demo

Durante la demo se debe mostrar:

- Página principal de la aplicación.
- Página `query.php`.
- Consultas disponibles:
  - Mobile Phones.
  - Population.
  - Life Expectancy.
  - GDP.
  - Childhood Mortality.
- Evidencia de que los datos vienen de RDS.

## 12. Lecciones Aprendidas

- AWS Academy restringe creación de roles IAM, por lo que se debe usar `LabInstanceProfile`.
- Las instancias privadas requieren NAT o endpoints para descargar paquetes y comunicarse con servicios AWS.
- SSM debe instalarse/iniciarse explícitamente en el bootstrap.
- La importación SQL automatizada reduce pasos manuales y errores de demo.
- Terraform permite reconstruir la infraestructura de forma repetible.
