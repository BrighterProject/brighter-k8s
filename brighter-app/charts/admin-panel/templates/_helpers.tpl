{{- define "admin-panel.fullname" -}}
{{- printf "%s-%s" .Release.Name "admin-panel" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "admin-panel.labels" -}}
app.kubernetes.io/name: admin-panel
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}

{{- define "admin-panel.selectorLabels" -}}
app.kubernetes.io/name: admin-panel
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
