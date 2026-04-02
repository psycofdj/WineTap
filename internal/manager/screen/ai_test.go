package screen

import (
	"testing"
)

func TestChatGPTQuery(t *testing.T) {
	/*
		name := "Domaine Thibert Père et Fils"
		prompt := fmt.Sprintf(
			"Tu es un expert en vins français. Rédige une courte description (2 à 3 phrases) "+
				"du domaine viticole « %s » : appellation, style des vins, réputation. "+
				"Je veux aussi l'adresse postale et le numéro de téléphone. "+
				"Répond moi sous forme d'un JSON: description, adresse, telephone. "+
				"Si tu ne connais pas l'un de ces champs, mets la valeur \"NC\".",
			name,
		)

		raw, err := chatGPTQuery(prompt)
		if err != nil {
			t.Fatalf("query error: %v", err)
		}
		t.Logf("raw response:\n%s", raw)

		jsonStr := extractJSONObject(raw)
		if jsonStr == "" {
			t.Fatalf("no JSON object found in response")
		}

		var info struct {
			Description string `json:"description"`
			Adresse     string `json:"adresse"`
			Telephone   string `json:"telephone"`
		}
		if err := json.Unmarshal([]byte(jsonStr), &info); err != nil {
			t.Fatalf("JSON parse error: %v\nraw JSON: %s", err, jsonStr)
		}

		t.Logf("description: %s", info.Description)
		t.Logf("adresse:     %s", info.Adresse)
		t.Logf("telephone:   %s", info.Telephone)

		if info.Description == "" {
			t.Error("expected non-empty description")
		}
	*/
	t.Logf("ok")
}
