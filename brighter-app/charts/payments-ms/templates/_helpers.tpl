{{- define "payments-ms.fullname" -}}
{{- printf "%s-%s" .Release.Name "payments-ms" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "payments-ms.labels" -}}
app.kubernetes.io/name: payments-ms
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}

{{- define "payments-ms.selectorLabels" -}}
app.kubernetes.io/name: payments-ms
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "payments-ms.jwtAuthMiddleware" -}}
{{ .Release.Name }}-jwt-auth
{{- end }}

{{- define "payments-ms.apiStripMiddleware" -}}
{{ .Release.Name }}-api-strip
{{- end }}
