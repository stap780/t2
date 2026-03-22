import Chartjs from "@stimulus-components/chartjs"

// Connects to data-controller="chartjs"
export default class extends Chartjs {
  connect() {
    super.connect()
  }

  get defaultOptions() {
    return {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: "top"
        }
      },
      scales: {
        y: {
          beginAtZero: true
        }
      }
    }
  }
}
