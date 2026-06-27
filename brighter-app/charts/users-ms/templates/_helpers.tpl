{{- define "users-ms.fullname" -}}
{{- printf "%s-%s" .Release.Name "users-ms" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "users-ms.labels" -}}
app.kubernetes.io/name: users-ms
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}

{{- define "users-ms.selectorLabels" -}}
app.kubernetes.io/name: users-ms
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- /* Name of the release-scoped jwt-auth middleware defined in the umbrella chart */ -}}
{{- define "users-ms.jwtAuthMiddleware" -}}
{{ .Release.Name }}-jwt-auth
{{- end }}

{{- define "users-ms.apiStripMiddleware" -}}
{{ .Release.Name }}-api-strip
{{- end }}
