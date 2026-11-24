# Session 26 design note: tracing the RAG app

This note gets uploaded during Session 26. Its trip through the pipeline is the trace I look at in Application Insights.

## What sends telemetry
The API and the worker use the Azure Monitor OpenTelemetry distro, plus the httpx instrumentation because the OpenAI SDK talks over httpx. The function app sends its own telemetry through the Functions host. All three sign in to Application Insights with the shared user-assigned managed identity, which has the Monitoring Metrics Publisher role.

## Keys off
Local authentication is off on Application Insights. The connection string only says where to send data. Without a valid Entra token, Application Insights rejects the data.

## Custom spans
The API wraps each step of a question in its own span: rag.embed, rag.vector_search and rag.chat. The rag.chat span carries the model name and the input, output and total token counts, so token use per question can be charted with KQL.

## What doesn't join up
An upload makes separate traces for the worker and the function. Event Grid doesn't pass trace context into the Service Bus message, and the Cosmos change feed doesn't carry one either, so each hop starts a new trace.

## Cost
Application Insights is workspace-based, so its data lands in the existing Log Analytics workspace. The first 5 GB a month are free, and a 1 GB daily cap stops a runaway loop from running up a bill.
