{{- define "notifications-ms.fullname" -}}
{{- printf "%s-%s" .Release.Name "notifications-ms" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "notifications-ms.labels" -}}
app.kubernetes.io/name: notifications-ms
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}

{{- define "notifications-ms.selectorLabels" -}}
app.kubernetes.io/name: notifications-ms
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "notifications-ms.jwtAuthMiddleware" -}}
{{ .Release.Name }}-jwt-auth
{{- end }}

{{- define "notifications-ms.apiStripMiddleware" -}}
{{ .Release.Name }}-api-strip
{{- end }}
