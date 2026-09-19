import express from "express";
import cors from "cors";
import multer from "multer";
import dotenv from "dotenv";
import fs from "fs";

dotenv.config();

const app = express();

// Enable full CORS for web browser clients (Flutter web on Edge/Chrome)
app.use(cors({ origin: "*" }));
app.use(express.json());

const upload = multer({ dest: "uploads/" });

const WORKSPACE_NAME = "vinays-workspace-qo2yi";
const WORKFLOW_ID = "indian-meal-nutrition-json-analyzer-1785338666664";

app.get("/", (req, res) => {
  res.json({
    status: "healthy",
    service: "Indian Meal Nutrition Analyzer Node Backend",
    workspace: WORKSPACE_NAME,
    workflow_id: WORKFLOW_ID
  });
});

app.post("/analyze-meal", upload.any(), async (req, res) => {
  if (!process.env.ROBOFLOW_API_KEY) {
    return res.status(500).json({
      success: false,
      error: "ROBOFLOW_API_KEY environment variable is not configured."
    });
  }

  const uploadedFile = req.file || (req.files && req.files[0]);
  if (!uploadedFile) {
    return res.status(400).json({ success: false, error: "No image uploaded" });
  }

  try {
    const imageBuffer = fs.readFileSync(uploadedFile.path);
    const base64Image = imageBuffer.toString("base64");

    const response = await fetch(
      `https://detect.roboflow.com/infer/workflows/${WORKSPACE_NAME}/${WORKFLOW_ID}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          api_key: process.env.ROBOFLOW_API_KEY,
          inputs: {
            image: {
              type: "base64",
              value: base64Image
            }
          }
        })
      }
    );

    const result = await response.json();

    if (!response.ok) {
      return res.status(response.status).json({
        success: false,
        error: result
      });
    }

    const output = result.outputs?.[0] || result[0] || result;

    if (output.json_parse_error === true) {
      return res.json({
        success: false,
        error: "Nutrition JSON could not be parsed.",
        raw: output.nutrition_report_raw
      });
    }

    return res.json({
      success: true,
      scale_reference: output.scale_reference,
      reference_object: output.reference_object,
      items: output.items,
      meal_totals: output.meal_totals,
      disclaimer: output.disclaimer
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: err.message
    });
  } finally {
    if (uploadedFile && fs.existsSync(uploadedFile.path)) {
      try {
        fs.unlinkSync(uploadedFile.path);
      } catch (e) {
        console.error("Failed to delete temp file:", e);
      }
    }
  }
});

const PORT = process.env.PORT || 3000;
// Bind to 0.0.0.0 to support both IPv4 (127.0.0.1) and IPv6 (::1) localhost resolutions
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Node Express backend running on http://0.0.0.0:${PORT}`);
});
