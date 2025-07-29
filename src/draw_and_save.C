void draw_and_save(const char* infile,
                   const char* histname="hADC",
                   const char* outdir="plots")
{
  gStyle->SetBatch(kTRUE);

  TFile f(infile);
  if (f.IsZombie()) { printf("Cannot open %s\n", infile); return; }

  TH1* h = (TH1*)f.Get(histname);
  if (!h) { printf("Histogram %s not found\n", histname); return; }

  gSystem->mkdir(outdir, kTRUE);
  TCanvas c("c","",1200,800);
  h->Draw();

  TString base = Form("%s/%s", outdir, histname);
  c.SaveAs(base + ".png");
  c.SaveAs(base + ".pdf");
}
