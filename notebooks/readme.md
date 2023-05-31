create the necessary python environment for papermill via 
`conda env create -f environment.yml`

Aftwards, activate the environment via 
`conda activate mints-reports`

Generate the notebook `data-download.ipynb` via the following command: 
`papermill data-download.ipynb ../website/test/data-download.ipynb`

