# Data Pipeline - Serverless + Spot Instances

Infraestrutura Terraform para um pipeline de processamento de dados na AWS utilizando arquitetura orientada a eventos com componentes serverless e instancias spot.

## Arquitetura

```
┌──────────┐    event     ┌──────────┐   message   ┌──────────┐   poll   ┌─────────────────────┐
│  S3      │─────────────▶│  Lambda  │────────────▶│  SQS     │◀─────────│  ASG                │
│  Bucket  │ ObjectCreated│ Metadata │ SendMessage │  Queue   │          │  5x t3.nano (spot)  │
│          │              │ Processor│             │          │          │  Workers            │
└──────────┘              └──────────┘             └──────────┘          └─────────────────────┘
```

### Fluxo

1. **S3 Bucket** - Recebe uploads de arquivos e dispara evento `s3:ObjectCreated:*`
2. **AWS Lambda** - Processa metadados do objeto (`HeadObject`) e envia um job como mensagem JSON para a fila SQS
3. **SQS Queue** - Armazena jobs com long polling (20s) e visibility timeout de 5 minutos
4. **Auto Scaling Group** - 5 instancias spot `t3.nano` executam um worker Python que consome mensagens da fila, processa e deleta

## Recursos Provisionados

| Recurso | Descricao |
|---------|-----------|
| `aws_s3_bucket` | Bucket para upload de arquivos |
| `aws_s3_bucket_notification` | Trigger de evento S3 → Lambda |
| `aws_lambda_function` | Funcao que extrai metadados e envia para SQS |
| `aws_sqs_queue` | Fila de jobs para processamento |
| `aws_launch_template` | Template com spot instances t3.nano |
| `aws_autoscaling_group` | Grupo com 5 instancias spot |
| `aws_security_group` | SG dos workers (egress only) |
| `aws_iam_role` (x2) | Roles para Lambda e EC2 |
| `aws_iam_instance_profile` | Profile para as instancias EC2 |

## Pre-requisitos

- Terraform >= 1.5.0
- AWS CLI configurado com credenciais validas
- Conta AWS com permissoes para criar os recursos listados

## Uso

```bash
# Copiar e editar variaveis
cp terraform.tfvars.example terraform.tfvars

# Inicializar providers
terraform init

# Visualizar plano de execucao
terraform plan

# Aplicar infraestrutura
terraform apply
```

## Variaveis

| Variavel | Descricao | Default |
|----------|-----------|---------|
| `aws_region` | Regiao AWS | `us-east-1` |
| `project_name` | Prefixo dos recursos | `data-pipeline` |
| `environment` | Nome do ambiente | `dev` |
| `bucket_name` | Nome do bucket S3 | (obrigatorio) |
| `instance_type` | Tipo da instancia EC2 | `t3.nano` |
| `asg_desired_capacity` | Quantidade desejada de instancias | `5` |
| `asg_min_size` | Minimo de instancias no ASG | `1` |
| `asg_max_size` | Maximo de instancias no ASG | `5` |
| `ami_id` | AMI customizada (opcional) | Amazon Linux 2023 |

## Outputs

| Output | Descricao |
|--------|-----------|
| `s3_bucket_name` | Nome do bucket S3 |
| `s3_bucket_arn` | ARN do bucket S3 |
| `lambda_function_name` | Nome da funcao Lambda |
| `lambda_function_arn` | ARN da funcao Lambda |
| `sqs_queue_url` | URL da fila SQS |
| `sqs_queue_arn` | ARN da fila SQS |
| `asg_name` | Nome do Auto Scaling Group |
| `launch_template_id` | ID do Launch Template |

## Estrutura do Projeto

```
.
├── terraform.tf              # Provider AWS + archive
├── variables.tf              # Variaveis de entrada
├── locals.tf                 # Tags comuns
├── s3.tf                     # S3 bucket + notificacao
├── lambda.tf                 # Lambda + IAM
├── lambda/
│   └── handler.py            # Codigo Python da Lambda
├── sqs.tf                    # Fila SQS + policy
├── compute.tf                # ASG + Launch Template + SG + IAM
├── user_data.sh.tpl          # Bootstrap script dos workers
├── outputs.tf                # Outputs
├── terraform.tfvars.example  # Exemplo de variaveis
└── README.md
```

## Customizacao do Worker

A logica de processamento dos workers esta em `user_data.sh.tpl`, na funcao `process_message()`. Altere essa funcao para implementar o processamento desejado:

```python
def process_message(message):
    body = json.loads(message["Body"])
    # body contém: bucket, key, size, etag, content_type, last_modified
    # Adicione sua logica de processamento aqui
```

## Testando a Arquitetura

Apos o `terraform apply`, siga os passos abaixo para validar o pipeline completo (S3 → Lambda → SQS → Workers).

### 1. Obter os nomes dos recursos

```bash
terraform output
```

### 2. Upload de arquivo de teste no S3

Envia um arquivo para o bucket, disparando o evento `s3:ObjectCreated:*` que aciona a Lambda.

```bash
echo '{"test": "data"}' > /tmp/test-file.json
aws s3 cp /tmp/test-file.json s3://$(terraform output -raw s3_bucket_name)/test-file.json --profile bianchi_aws
```

### 3. Verificar execucao da Lambda

Consulta os logs mais recentes da funcao Lambda. Voce deve ver a linha `Sent job to SQS: bucket=..., key=test-file.json, size=...`.

```bash
aws logs tail /aws/lambda/$(terraform output -raw lambda_function_name) --since 5m --profile bianchi_aws
```

### 4. Verificar profundidade da fila SQS

- `ApproximateNumberOfMessages` = mensagens aguardando consumo
- `ApproximateNumberOfMessagesNotVisible` = mensagens sendo processadas pelos workers

```bash
aws sqs get-queue-attributes \
  --queue-url $(terraform output -raw sqs_queue_url) \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --profile bianchi_aws
```

### 5. Verificar instancias do ASG

Confirma que as instancias spot foram lancadas e estao no estado `InService`.

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw asg_name) \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState]' \
  --output table \
  --profile bianchi_aws
```

### 6. Verificar logs dos workers

Acessa o log do worker em uma das instancias via SSM.

> **Nota:** Requer a policy `AmazonSSMManagedInstanceCore` na role dos workers.

```bash
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw asg_name) \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text \
  --profile bianchi_aws)

aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cat /var/log/worker.log"]' \
  --output text \
  --profile bianchi_aws
```

### 7. Teste de carga (smoke test)

Envia 3 arquivos em sequencia para validar o processamento concorrente. Se `ApproximateNumberOfMessages` retornar `0`, o pipeline completo esta funcionando.

```bash
for i in 1 2 3; do
  echo "{\"batch\": $i}" | aws s3 cp - s3://$(terraform output -raw s3_bucket_name)/test-batch-$i.json --profile bianchi_aws
done

sleep 10
aws sqs get-queue-attributes \
  --queue-url $(terraform output -raw sqs_queue_url) \
  --attribute-names ApproximateNumberOfMessages \
  --profile bianchi_aws
```

### Resumo de validacao

| Passo | O que valida |
|-------|--------------|
| Upload S3 | Bucket existe e notificacao esta configurada |
| Logs Lambda | Evento S3 aciona Lambda, Lambda le metadados e envia para SQS |
| Atributos SQS | Mensagens chegam na fila |
| Instancias ASG | Instancias spot foram lancadas com sucesso |
| Fila zerada | Workers estao consumindo e processando mensagens |

## Destruindo a Infraestrutura

```bash
terraform destroy
```
