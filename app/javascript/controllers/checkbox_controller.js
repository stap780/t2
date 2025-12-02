import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="checkbox" - one of use in Filter
export default class extends Controller {
  static targets = [ "btn", "box" ]
  connect() {
    // console.log('connected Checkbox');
  }

  toggle(e) {
  }
  toggleOne(e) {
    // console.log(e);
    var chks = this.btnTargets;
    // console.log('chks => ', chks);
    // chks.forEach(checkbox => checkbox.checked = false)
    if ( e.target.checked == true){
      chks.forEach((chk, index) => {
        if (chk != e.target ) {
          chk.checked = false;
        }
      });
    } else {
      e.target.checked == false
    };
  }

}

//
//
// <div data-controller="checkbox">
// <input type="checkbox" data-checkbox-target="btn" data-action="change->checkbox#toggle">
// <input type="checkbox" data-checkbox-target="box" data-action="change->checkbox#toggleOne">
// </div>
//
//

