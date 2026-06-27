{{- define "bookings-ms.fullname" -}}
{{- printf "%s-%s" .Release.Name "bookings-ms" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "bookings-ms.labels" -}}
app.kubernetes.io/name: bookings-ms
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}

{{- define "bookings-ms.selectorLabels" -}}
app.kubernetes.io/name: bookings-ms
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "bookings-ms.jwtAuthMiddleware" -}}
{{ .Release.Name }}-jwt-auth
{{- end }}

{{- define "bookings-ms.apiStripMiddleware" -}}
{{ .Release.Name }}-api-strip
{{- end }}
