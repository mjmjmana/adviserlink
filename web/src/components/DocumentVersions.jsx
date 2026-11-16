import { useCallback, useEffect, useState } from "react";
import { Download, Loader2, Upload, X } from "lucide-react";
import { getDocumentVersions, uploadDocumentVersion, downloadDocumentVersion } from "@/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { format } from "date-fns";

export function DocumentVersions({ documentId, user, canUpload = true, onUpload }) {
  const [versions, setVersions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [showUpload, setShowUpload] = useState(false);
  const [comment, setComment] = useState("");
  const [file, setFile] = useState(null);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState({ type: "", text: "" });

  const load = useCallback(async () => {
    if (!documentId) return;
    try {
      const data = await getDocumentVersions(documentId);
      setVersions(data);
    } catch (e) {
      setError(e.message);
    }
  }, [documentId]);

  useEffect(() => {
    load();
  }, [load]);

  const handleFileChange = (e) => {
    const f = e.target.files[0];
    if (f) {
      if (!f.type.startsWith("application/pdf") && !f.type.startsWith("application/") && !f.type.startsWith("image/")) {
        setMsg({ type: "error", text: "Only PDF, Word, and image files are allowed." });
        return;
      }
      if (f.size > 10 * 1024 * 1024) {
        setMsg({ type: "error", text: "File too large (max 10MB)." });
        return;
      }
      setFile(f);
    }
  };

  const handleUpload = async (e) => {
    e.preventDefault();
    if (!file) return;
    setUploading(true);
    setMsg({ type: "", text: "" });
    try {
      await uploadDocumentVersion(documentId, file, comment || null);
      setMsg({ type: "ok", text: "New version uploaded." });
      setFile(null);
      setComment("");
      setShowUpload(false);
      load();
      onUpload?.();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setUploading(false);
    }
  };

  const handleDownload = async (version) => {
    try {
      await downloadDocumentVersion(version.version_id, version.filename);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    }
  };

  const formatSize = (bytes) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  return (
    <div className="grid gap-3">
      <div className="flex items-center justify-between">
        <CardTitle className="text-lg">Versions</CardTitle>
        {user.role === "student" && canUpload && (
          <Button variant="outline" size="sm" onClick={() => setShowUpload(true)}>
            <Upload className="h-4 w-4 mr-2" /> Upload Version
          </Button>
        )}
      </div>

      <Notice msg={msg} />

      {showUpload && (
        <Card className="p-4 border-primary/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Upload New Version</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-3">
            <form onSubmit={handleUpload} className="grid gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="version-file">File *</Label>
                <Input id="version-file" type="file" accept=".pdf,.doc,.docx,.png,.jpg,.jpeg" onChange={handleFileChange} required />
                {file && <p className="text-sm text-muted-foreground">{file.name} · {formatSize(file.size)}</p>}
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="version-comment">Comment</Label>
                <Input id="version-comment" value={comment} onChange={(e) => setComment(e.target.value)} placeholder="What changed in this version?" maxLength={500} />
              </div>
              <div className="flex gap-2">
                <Button type="submit" disabled={uploading || !file}>
                  {uploading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
                  Upload
                </Button>
                <Button type="button" variant="outline" onClick={() => { setShowUpload(false); setFile(null); setComment(""); }}>
                  <X className="h-4 w-4 mr-1" /> Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {versions.length === 0 ? (
        <Card className="p-8 text-center border-dashed">
          <p className="text-muted-foreground">No versions yet.</p>
        </Card>
      ) : (
        <div className="grid gap-2">
          {versions.map((v) => (
            <Card key={v.version_id} className="p-3">
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-3 min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <Badge variant="outline">v{v.version_number}</Badge>
                    <span className="font-medium truncate">{v.filename}</span>
                  </div>
                  <div className="flex items-center gap-3 text-sm text-muted-foreground">
                    <span>{formatSize(v.size_bytes)}</span>
                    <span>by {v.uploaded_by_name}</span>
                    <span>{format(new Date(v.created_at), "MMM d, yyyy HH:mm")}</span>
                  </div>
                  {v.comment && <p className="text-sm text-muted-foreground mt-1">{v.comment}</p>}
                </div>
                <div className="flex gap-2 shrink-0">
                  <Button variant="outline" size="icon" onClick={() => handleDownload(v)} aria-label="Download">
                    <Download className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

export default DocumentVersions;