# Arquitectura del Proyecto Final AWS

## Descripción General

Esta arquitectura implementa una aplicación web PHP segura, escalable y altamente disponible en AWS. Sigue un modelo de tres capas (presentación, aplicación, datos) con aislamiento de red completo entre cada nivel.

## Diagrama de Arquitectura

El diagrama completo está en `architecture.mmd` (formato Mermaid).

### Cómo renderizar el diagrama

1. **VS Code**: Instala la extensión "Markdown Preview Mermaid Support" y abre el archivo .mmd
2. **GitHub**: Sube el archivo .mmd y GitHub lo renderiza automáticamente
3. **Mermaid Live Editor**: Copia el contenido en [https://mermaid.live](https://mermaid.live)
4. **CLI**: Usa `mmdc -i architecture.mmd -o architecture.png` (requiere `@mermaid-js/mermaid-cli`)

## Componentes Principales

| Componente | Servicio AWS | Propósito |
|---|---|---|
| Red | VPC + 6 subnets | Aislamiento y segmentación |
| Acceso público | Internet Gateway | Entrada de tráfico web |
| NAT | NAT Gateway | Salida a internet para instancias privadas |
| Balanceo | Application Load Balancer | Distribución de tráfico HTTP |
| Cómputo | EC2 (Auto Scaling Group) | Servidores PHP |
| Base de datos | RDS MySQL | Almacenamiento de datos |
| Credenciales | Secrets Manager | Gestión segura de contraseñas |
| Administración | SSM Session Manager | Acceso sin SSH |

## Flujos de Tráfico

### Flujo de usuario web
```
Usuario → Internet → IGW → ALB (público) → EC2 (privado) → RDS (DB)
```

### Flujo de administración
```
Admin → SSM Session Manager → EC2 (privado)
```

### Flujo de credenciales
```
EC2 → IAM Role → Secrets Manager API → Credenciales RDS
```

### Flujo de salida a internet (EC2)
```
EC2 (privado) → NAT Gateway (público) → IGW → Internet
```

## Decisiones de Diseño

### 1. NAT Gateway único (vs uno por AZ)
- **Decisión**: Un solo NAT Gateway en la primera subnet pública
- **Razón**: Reduce costos (~$32/mes de ahorro). En un entorno de laboratorio con presupuesto limitado, la alta disponibilidad del NAT no es crítica
- **Tradeoff**: Si la AZ1 falla, las instancias en AZ2 pierden acceso a internet saliente. Las instancias existentes siguen sirviendo tráfico pero no pueden refrescar credenciales

### 2. RDS Single-AZ (vs Multi-AZ)
- **Decisión**: Una sola instancia RDS sin Multi-AZ
- **Razón**: Restricción del laboratorio (presupuesto) y el código PHP usa `DBInstances[0]`
- **Tradeoff**: Sin failover automático. Si RDS falla, la app muestra errores de conexión hasta que AWS recupere la instancia

### 3. Credenciales gestionadas por RDS (vs secret manual)
- **Decisión**: `manage_master_user_password = true` en Terraform
- **Razón**: El código PHP filtra secretos por prefijo `rds!`. Solo los secretos creados automáticamente por RDS tienen este prefijo
- **Tradeoff**: No se puede personalizar el nombre del secreto, pero es el único método compatible con la aplicación

### 4. Sin SSH, solo SSM Session Manager
- **Decisión**: No abrir puerto 22, no asignar key pair
- **Razón**: Mejora la seguridad eliminando un vector de ataque. SSM proporciona acceso auditado sin necesidad de gestionar llaves SSH
- **Tradeoff**: Requiere que el NAT Gateway funcione para que SSM se conecte (las instancias necesitan alcanzar los endpoints de SSM)

### 5. Bug fix via sed en User Data
- **Decisión**: Aplicar `sed` al archivo lifeexpectancy.php durante el bootstrap
- **Razón**: Simple, idempotente, y se aplica automáticamente a cada nueva instancia del ASG
- **Tradeoff**: Si el formato del archivo cambia, el sed podría no encontrar el patrón. Para este proyecto, el archivo es estático

### 6. Import SQL manual (vs automático en User Data)
- **Decisión**: Script separado ejecutado manualmente vía SSM
- **Razón**: Evita race conditions (RDS puede no estar listo cuando la primera EC2 arranca). Además, es una operación única que no debe repetirse en cada instancia
- **Tradeoff**: Requiere un paso manual post-despliegue

## Evaluación de Seguridad

| Control | Implementación |
|---|---|
| Aislamiento de red | 3 capas de subnets con security groups restrictivos |
| Sin acceso público a backend | EC2 en subnets privadas, sin IP pública |
| Sin SSH | Puerto 22 cerrado, acceso solo vía SSM |
| Credenciales seguras | Secrets Manager con rotación automática de RDS |
| IAM least privilege | Solo permisos de SSM, lectura de secretos y describe RDS |
| Base de datos protegida | RDS en subnet DB, solo accesible desde EC2 SG |
| Sin hardcoding | Ninguna credencial en código fuente o variables de Terraform |

## Evaluación de Escalabilidad

| Aspecto | Mecanismo |
|---|---|
| Escalado horizontal | Auto Scaling Group (2-4 instancias) |
| Política de escalado | Target Tracking: CPU al 50% |
| Distribución de carga | ALB distribuye entre instancias sanas |
| Multi-AZ | Instancias en 2 zonas de disponibilidad |
| Health checks | ALB verifica salud cada 30s, ASG reemplaza instancias fallidas |
| Bootstrap automático | User Data configura cada nueva instancia completamente |
| Grace period | 300s para que el bootstrap complete antes de evaluar salud |

## Evaluación de Alta Disponibilidad

| Escenario de falla | Respuesta del sistema |
|---|---|
| Una instancia EC2 falla | ASG la reemplaza automáticamente en ~5 min |
| Una AZ completa falla | ALB redirige tráfico a la otra AZ |
| Apache se detiene en una instancia | Health check falla → ASG reemplaza |
| RDS falla | Sin failover automático (Single-AZ). Requiere recuperación manual |
| NAT Gateway falla | Instancias existentes siguen sirviendo, pero nuevas no pueden bootstrapear |
