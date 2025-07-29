#include "TH1F.h"
#include "TFile.h"
#include <iostream>

int main() {
  TH1F h("h","test",100,0,10);
  h.Fill(3.14);
  TFile f("test.root","RECREATE");
  h.Write();
  f.Close();
  std::cout << "OK\n";
  return 0;
}
