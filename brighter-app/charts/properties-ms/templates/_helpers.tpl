{{- define "properties-ms.fullname" -}}
{{- printf "%s-%s" .Release.Name "properties-ms" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "properties-ms.labels" -}}
app.kubernetes.io/name: properties-ms
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}

{{- define "properties-ms.selectorLabels" -}}
app.kubernetes.io/name: properties-ms
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "properties-ms.jwtAuthMiddleware" -}}
{{ .Release.Name }}-jwt-auth
{{- end }}

{{- define "properties-ms.apiStripMiddleware" -}}
{{ .Release.Name }}-api-strip
{{- end }}
