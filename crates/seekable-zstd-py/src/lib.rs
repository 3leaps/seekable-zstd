use pyo3::prelude::*;
use pyo3::types::PyBytes;
use seekable_zstd_core::ParallelDecoder;

#[pyclass]
struct Reader {
    inner: ParallelDecoder,
}

#[pymethods]
impl Reader {
    #[new]
    fn new(path: &str) -> PyResult<Self> {
        let inner = ParallelDecoder::open(path)
            .map_err(|e| PyErr::new::<pyo3::exceptions::PyIOError, _>(e.to_string()))?;
        Ok(Reader { inner })
    }

    fn size(&self) -> u64 {
        self.inner.size()
    }

    fn frame_count(&self) -> u64 {
        self.inner.frame_count()
    }

    fn read_range(&self, py: Python, start: u64, end: u64) -> PyResult<Py<PyBytes>> {
        let range = vec![(start, end)];
        let results = self
            .inner
            .read_ranges(&range)
            .map_err(|e| PyErr::new::<pyo3::exceptions::PyIOError, _>(e.to_string()))?;

        // Since we only requested one range, we expect one result
        if let Some(data) = results.first() {
            Ok(PyBytes::new(py, data).into())
        } else {
            // Should not happen for non-empty input
            Ok(PyBytes::new(py, &[]).into())
        }
    }

    fn read_ranges(&self, py: Python, ranges: Vec<(u64, u64)>) -> PyResult<Vec<Py<PyBytes>>> {
        let results = self
            .inner
            .read_ranges(&ranges)
            .map_err(|e| PyErr::new::<pyo3::exceptions::PyIOError, _>(e.to_string()))?;

        let mut py_results = Vec::with_capacity(results.len());
        for data in results {
            py_results.push(PyBytes::new(py, &data).into());
        }
        Ok(py_results)
    }

    fn __enter__(slf: PyRef<'_, Self>) -> PyRef<'_, Self> {
        slf
    }

    #[pyo3(signature = (_exc_type=None, _exc_val=None, _exc_tb=None))]
    fn __exit__(
        &self,
        _exc_type: Option<PyObject>,
        _exc_val: Option<PyObject>,
        _exc_tb: Option<PyObject>,
    ) -> bool {
        // No cleanup needed - ParallelDecoder doesn't hold open file handles
        // Return false to not suppress exceptions
        false
    }
}

#[pymodule]
fn seekable_zstd(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<Reader>()?;
    Ok(())
}
