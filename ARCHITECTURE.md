# AWS Architecture

A simple AWS architecture using an Application Load Balancer in front of an
ECS service, with an S3 bucket for storage.

## Overview

Incoming traffic from the internet is routed through an Application Load
Balancer (ALB), which distributes requests across tasks running in an Amazon
ECS service. The ECS service runs containerized application tasks and scales
to meet demand. Tasks have read access to the `secret-plans` S3 bucket.

## Diagram

```mermaid
flowchart LR
    user([Internet / Users])
    alb[Application Load Balancer]
    s3[(S3: secret-plans)]

    subgraph ECS["Amazon ECS Service"]
        task1[Task 1]
        task2[Task 2]
        task3[Task N]
    end

    user --> alb
    alb --> task1
    alb --> task2
    alb --> task3
    ECS -- read --> s3
```

## Components

| Component | Description |
| --- | --- |
| **Application Load Balancer** | Public entry point. Terminates connections, performs health checks, and distributes traffic across ECS tasks. |
| **Amazon ECS Service** | Runs and maintains the desired number of containerized tasks. Registers tasks as targets behind the ALB and scales based on load. Has read-only access to the `secret-plans` S3 bucket. |
| **S3 Bucket (`secret-plans`)** | Object storage bucket. The ECS task role grants read-only access (e.g. `s3:GetObject`, `s3:ListBucket`) so tasks can fetch objects but not modify them. |

## Request Flow

1. A user sends a request over the internet.
2. The Application Load Balancer receives the request and selects a healthy
   ECS task from its target group.
3. The chosen ECS task processes the request and returns a response back
   through the ALB to the user.
