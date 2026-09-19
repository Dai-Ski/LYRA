/**
 * Lyra — Minimal Razorpay Support & Checkout Integration
 * Public Live Key: rzp_live_TdmI0FfRWhdkVO
 */

(function () {
  const RAZORPAY_KEY_ID = "rzp_live_TdmI0FfRWhdkVO";

  // Preload Razorpay Checkout SDK
  function loadRazorpaySdk(callback) {
    if (window.Razorpay) {
      if (callback) callback();
      return;
    }
    const script = document.createElement("script");
    script.src = "https://checkout.razorpay.com/v1/checkout.js";
    script.async = true;
    script.onload = function () {
      if (callback) callback();
    };
    script.onerror = function () {
      console.error("Failed to load Razorpay SDK.");
    };
    document.head.appendChild(script);
  }

  loadRazorpaySdk();

  // Create Minimal Modal DOM Structure
  function createModal() {
    let dialog = document.getElementById("razorpay-modal");
    if (dialog) return dialog;

    dialog = document.createElement("dialog");
    dialog.id = "razorpay-modal";
    dialog.className = "rzp-modal-dialog";

    dialog.innerHTML = `
      <div class="rzp-modal-card" role="document">
        <button type="button" class="rzp-close-btn" id="rzp-close-btn" aria-label="Close">✕</button>

        <div class="rzp-header">
          <div class="rzp-avatar">
            <img src="cat.png" alt="Daiski Cat">
          </div>
          <div class="rzp-title-wrap">
            <h2 class="rzp-title">Support <span class="font-lyra">Lyra</span></h2>
            <span class="rzp-sub">Select a tip amount</span>
          </div>
        </div>

        <!-- Preset Amount Grid -->
        <div class="rzp-presets-grid" id="rzp-presets-grid">
          <button type="button" class="rzp-preset-btn" data-amount="50">₹50</button>
          <button type="button" class="rzp-preset-btn" data-amount="100">₹100</button>
          <button type="button" class="rzp-preset-btn" data-amount="250">₹250</button>
          <button type="button" class="rzp-preset-btn" data-amount="500">₹500</button>
          <button type="button" class="rzp-preset-btn" data-amount="1000">₹1,000</button>
          <button type="button" class="rzp-preset-btn" data-amount="2000">₹2,000</button>
        </div>

        <!-- Custom Amount Single-Line Form -->
        <form class="rzp-custom-form" id="rzp-custom-form">
          <div class="rzp-custom-box">
            <span class="rzp-currency-symbol">₹</span>
            <input type="number" class="rzp-custom-input" id="rzp-custom-input" placeholder="Other amount" min="10" step="10" aria-label="Custom tip amount">
            <button type="submit" class="rzp-custom-pay-btn" id="rzp-custom-pay-btn">Pay</button>
          </div>
        </form>
      </div>
    `;

    document.body.appendChild(dialog);
    attachModalEvents(dialog);
    return dialog;
  }

  function attachModalEvents(dialog) {
    const closeBtn = dialog.querySelector("#rzp-close-btn");
    const presetBtns = dialog.querySelectorAll(".rzp-preset-btn");
    const customForm = dialog.querySelector("#rzp-custom-form");
    const customInput = dialog.querySelector("#rzp-custom-input");

    // Set default selection (₹100)
    let selectedBtn = dialog.querySelector('.rzp-preset-btn[data-amount="100"]');
    if (selectedBtn) {
      selectedBtn.classList.add("active");
      customInput.value = "100";
    }

    // When tapping ANY number button: select it, update the input below, do NOT auto-submit
    presetBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        presetBtns.forEach((b) => b.classList.remove("active"));
        btn.classList.add("active");
        customInput.value = btn.dataset.amount;
      });
    });

    // When user types in custom input: sync active preset state
    customInput.addEventListener("input", () => {
      const val = customInput.value.trim();
      presetBtns.forEach((b) => {
        if (b.dataset.amount === val) {
          b.classList.add("active");
        } else {
          b.classList.remove("active");
        }
      });
    });

    // When clicking Pay / submitting form: close modal and open Razorpay
    customForm.addEventListener("submit", (e) => {
      e.preventDefault();
      const rawVal = parseInt(customInput.value, 10);
      const activeBtn = dialog.querySelector(".rzp-preset-btn.active");
      const activeVal = activeBtn ? parseInt(activeBtn.dataset.amount, 10) : 100;
      const amount = !isNaN(rawVal) && rawVal >= 10 ? rawVal : activeVal;
      closeModal();
      launchRazorpay(amount);
    });

    // Close on backdrop click
    dialog.addEventListener("click", (e) => {
      const card = dialog.querySelector(".rzp-modal-card");
      if (!card) return;
      const rect = card.getBoundingClientRect();
      const inCard =
        rect.top <= e.clientY &&
        e.clientY <= rect.top + rect.height &&
        rect.left <= e.clientX &&
        e.clientX <= rect.left + rect.width;
      if (!inCard) {
        closeModal();
      }
    });

    if (closeBtn) {
      closeBtn.addEventListener("click", closeModal);
    }

    dialog.addEventListener("cancel", (e) => {
      e.preventDefault();
      closeModal();
    });
  }

  // Open Razorpay Standard Checkout
  function launchRazorpay(amountInRupees) {
    loadRazorpaySdk(() => {
      if (!window.Razorpay) {
        alert("Unable to load Razorpay. Please check your network connection.");
        return;
      }

      const options = {
        key: RAZORPAY_KEY_ID,
        amount: amountInRupees * 100, // in paise
        currency: "INR",
        name: "Lyra",
        description: "Support Lyra Development",
        image: "https://dai-ski.github.io/LYRA/apple-touch-icon.png",
        theme: {
          color: "#0071e3"
        },
        handler: function (response) {
          alert(
            "Thank you for supporting Lyra! 💖\nPayment ID: " +
              response.razorpay_payment_id
          );
        },
        modal: {
          ondismiss: function () {
            console.log("Razorpay checkout closed by user.");
          }
        }
      };

      try {
        const rzp = new window.Razorpay(options);
        rzp.on("payment.failed", function (response) {
          alert("Payment failed: " + (response.error.description || "Incomplete payment"));
        });
        rzp.open();
      } catch (err) {
        console.error("Razorpay initiation error:", err);
      }
    });
  }

  function openModal() {
    const dialog = createModal();
    const customInput = dialog.querySelector("#rzp-custom-input");
    const presetBtns = dialog.querySelectorAll(".rzp-preset-btn");

    presetBtns.forEach((btn) => {
      if (btn.dataset.amount === "100") {
        btn.classList.add("active");
      } else {
        btn.classList.remove("active");
      }
    });
    if (customInput) customInput.value = "100";

    if (typeof dialog.showModal === "function") {
      dialog.showModal();
    } else {
      dialog.setAttribute("open", "");
    }
  }

  function closeModal() {
    const dialog = document.getElementById("razorpay-modal");
    if (dialog) {
      if (typeof dialog.close === "function") {
        dialog.close();
      } else {
        dialog.removeAttribute("open");
      }
    }
  }

  // Global exports
  window.openRazorpayModal = function (e) {
    if (e && typeof e.preventDefault === "function") e.preventDefault();
    openModal();
  };

  window.closeRazorpayModal = closeModal;
  window.launchRazorpayDirect = launchRazorpay;

  // Auto-bind to existing Razorpay buttons
  function bindRazorpayButtons() {
    document.querySelectorAll(".razorpay-btn").forEach((btn) => {
      if (!btn.dataset.rzpBound) {
        btn.dataset.rzpBound = "true";
        btn.addEventListener("click", (e) => {
          e.preventDefault();
          openModal();
        });
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bindRazorpayButtons);
  } else {
    bindRazorpayButtons();
  }
})();
