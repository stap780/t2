// https://github.com/adrienpoly/stimulus-flatpickr
import Flatpickr from 'stimulus-flatpickr';

// Connects to data-controller="flatpickr"
export default class extends Flatpickr {

  connect() {
    //console.log("connected flatpickr")
    // console.log("connected flatpickr", this.element)
 
    super.connect();

   }


}
