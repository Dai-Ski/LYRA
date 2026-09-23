/**
 * Lyra — Support & Checkout Integration (Razorpay & PayPal)
 * Razorpay Public Live Key: rzp_live_TdmI0FfRWhdkVO
 * PayPal Live Client ID: BAAW1RyQ4cPoLl7E61-GFT2n6L6P5E3SBEuCm__GFcDlS5X26jHCd7H0IUVBZGhzBSQJhDKKszO4wuC7mU
 */

(function () {
  const RAZORPAY_KEY_ID = "rzp_live_TdmI0FfRWhdkVO";
  const PAYPAL_CLIENT_ID = "BAAW1RyQ4cPoLl7E61-GFT2n6L6P5E3SBEuCm__GFcDlS5X26jHCd7H0IUVBZGhzBSQJhDKKszO4wuC7mU";

  // Preload Razorpay Checkout SDK
  function loadRazorpaySdk(callback) {
    if (window.Razorpay) {
      if (callback) callback();
      return;
    }
    const existing = document.querySelector('script[src*="checkout.razorpay.com"]');
    if (existing) {
      existing.addEventListener("load", () => {
        if (callback) callback();
      });
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

  // Preload PayPal JavaScript SDK
  function loadPayPalSdk(callback) {
    if (window.paypal && window.paypal.Buttons) {
      if (callback) callback();
      return;
    }
    const existing = document.querySelector('script[src*="paypal.com/sdk/js"]');
    if (existing) {
      existing.addEventListener("load", () => {
        if (callback) callback();
      });
      return;
    }
    const script = document.createElement("script");
    script.src = `https://www.paypal.com/sdk/js?client-id=${PAYPAL_CLIENT_ID}&currency=USD&components=buttons,applepay&enable-funding=venmo,card,applepay,paylater`;
    script.async = true;
    script.onload = function () {
      if (callback) callback();
    };
    script.onerror = function (err) {
      console.error("Failed to load PayPal SDK.", err);
    };
    document.head.appendChild(script);
  }

  loadRazorpaySdk();
  loadPayPalSdk();

  // --------------------------------------------------------------------------
  // 1. RAZORPAY MODAL (Domestic / INR)
  // --------------------------------------------------------------------------
  function createRazorpayModal() {
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
            <span class="rzp-sub">Select a tip amount (INR)</span>
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
    attachRazorpayModalEvents(dialog);
    return dialog;
  }

  function attachRazorpayModalEvents(dialog) {
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

    presetBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        presetBtns.forEach((b) => b.classList.remove("active"));
        btn.classList.add("active");
        customInput.value = btn.dataset.amount;
      });
    });

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

    customForm.addEventListener("submit", (e) => {
      e.preventDefault();
      const rawVal = parseInt(customInput.value, 10);
      const activeBtn = dialog.querySelector(".rzp-preset-btn.active");
      const activeVal = activeBtn ? parseInt(activeBtn.dataset.amount, 10) : 100;
      const amount = !isNaN(rawVal) && rawVal >= 10 ? rawVal : activeVal;
      closeRazorpayModal();
      launchRazorpay(amount);
    });

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
        closeRazorpayModal();
      }
    });

    if (closeBtn) {
      closeBtn.addEventListener("click", closeRazorpayModal);
    }

    dialog.addEventListener("cancel", (e) => {
      e.preventDefault();
      closeRazorpayModal();
    });
  }

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

  function openRazorpayModal() {
    const dialog = createRazorpayModal();
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

  function closeRazorpayModal() {
    const dialog = document.getElementById("razorpay-modal");
    if (dialog) {
      if (typeof dialog.close === "function") {
        dialog.close();
      } else {
        dialog.removeAttribute("open");
      }
    }
  }

  // --------------------------------------------------------------------------
  // 2. PAYPAL MODAL (International / USD)
  // --------------------------------------------------------------------------
  function getSelectedPayPalAmount(dialog) {
    if (!dialog) dialog = document.getElementById("paypal-modal");
    const customInput = dialog ? dialog.querySelector("#paypal-custom-input") : null;
    if (customInput && customInput.value.trim() !== "") {
      const val = parseFloat(customInput.value);
      if (!isNaN(val) && val >= 1) return val;
    }
    const activeBtn = dialog ? dialog.querySelector(".paypal-preset-btn.active") : null;
    if (activeBtn) {
      const val = parseFloat(activeBtn.dataset.amount);
      if (!isNaN(val) && val >= 1) return val;
    }
    return 5;
  }

  function createPayPalModal() {
    let dialog = document.getElementById("paypal-modal");
    if (dialog) return dialog;

    dialog = document.createElement("dialog");
    dialog.id = "paypal-modal";
    dialog.className = "rzp-modal-dialog";

    dialog.innerHTML = `
      <div class="rzp-modal-card" role="document">
        <button type="button" class="rzp-close-btn" id="paypal-close-btn" aria-label="Close">✕</button>

        <div class="rzp-header">
          <div class="rzp-avatar">
            <img src="cat.png" alt="Daiski Cat">
          </div>
          <div class="rzp-title-wrap">
            <h2 class="rzp-title">Support <span class="font-lyra">Lyra</span></h2>
            <span class="rzp-sub">Apple Pay, PayPal, Cards (USD)</span>
          </div>
        </div>

        <!-- Preset Amount Grid ($ USD) -->
        <div class="rzp-presets-grid" id="paypal-presets-grid">
          <button type="button" class="rzp-preset-btn paypal-preset-btn" data-amount="2">$2</button>
          <button type="button" class="rzp-preset-btn paypal-preset-btn" data-amount="5">$5</button>
          <button type="button" class="rzp-preset-btn paypal-preset-btn" data-amount="10">$10</button>
          <button type="button" class="rzp-preset-btn paypal-preset-btn" data-amount="20">$20</button>
          <button type="button" class="rzp-preset-btn paypal-preset-btn" data-amount="50">$50</button>
          <button type="button" class="rzp-preset-btn paypal-preset-btn" data-amount="100">$100</button>
        </div>

        <!-- Custom Amount Box -->
        <div class="rzp-custom-form" id="paypal-custom-form">
          <div class="rzp-custom-box paypal-custom-box">
            <span class="rzp-currency-symbol">$</span>
            <input type="number" class="rzp-custom-input" id="paypal-custom-input" placeholder="Other amount" min="1" step="any" aria-label="Custom USD tip amount">
          </div>
        </div>

        <!-- PayPal Smart Button SDK Container -->
        <div id="paypal-sdk-button-container" class="paypal-sdk-container">
          <div class="paypal-sdk-loading">Loading PayPal...</div>
        </div>
      </div>
    `;

    document.body.appendChild(dialog);
    attachPayPalModalEvents(dialog);
    renderPayPalButtons(dialog);
    return dialog;
  }

  function attachPayPalModalEvents(dialog) {
    const closeBtn = dialog.querySelector("#paypal-close-btn");
    const presetBtns = dialog.querySelectorAll(".paypal-preset-btn");
    const customInput = dialog.querySelector("#paypal-custom-input");

    // Set default selection ($5)
    let selectedBtn = dialog.querySelector('.paypal-preset-btn[data-amount="5"]');
    if (selectedBtn) {
      selectedBtn.classList.add("active");
      customInput.value = "5";
    }

    presetBtns.forEach((btn) => {
      btn.addEventListener("click", () => {
        presetBtns.forEach((b) => b.classList.remove("active"));
        btn.classList.add("active");
        customInput.value = btn.dataset.amount;
      });
    });

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
        closePayPalModal();
      }
    });

    if (closeBtn) {
      closeBtn.addEventListener("click", closePayPalModal);
    }

    dialog.addEventListener("cancel", (e) => {
      e.preventDefault();
      closePayPalModal();
    });
  }

  function renderPayPalButtons(dialog) {
    const container = dialog.querySelector("#paypal-sdk-button-container");
    if (!container) return;

    loadPayPalSdk(() => {
      if (!window.paypal || !window.paypal.Buttons) {
        container.innerHTML = `<div class="paypal-sdk-loading">Unable to load PayPal</div>`;
        return;
      }

      container.innerHTML = "";

      try {
        window.paypal.Buttons({
          style: {
            layout: "vertical",
            color: "gold",
            shape: "rect",
            label: "paypal",
            height: 40
          },
          createOrder: function (data, actions) {
            const amount = getSelectedPayPalAmount(dialog);
            return actions.order.create({
              purchase_units: [
                {
                  amount: {
                    currency_code: "USD",
                    value: amount.toFixed(2)
                  },
                  description: "Support Lyra Development"
                }
              ]
            });
          },
          onApprove: function (data, actions) {
            return actions.order.capture().then(function (details) {
              const name =
                details.payer && details.payer.name && details.payer.name.given_name
                  ? details.payer.name.given_name
                  : "friend";
              alert("Thank you for supporting Lyra, " + name + "! 💖");
              closePayPalModal();
            });
          },
          onError: function (err) {
            console.error("PayPal error:", err);
          },
          onCancel: function () {
            console.log("PayPal payment cancelled by user.");
          }
        }).render("#paypal-sdk-button-container");
      } catch (err) {
        console.error("Error rendering PayPal buttons:", err);
      }
    });
  }

  function openPayPalModal() {
    const dialog = createPayPalModal();
    const customInput = dialog.querySelector("#paypal-custom-input");
    const presetBtns = dialog.querySelectorAll(".paypal-preset-btn");

    presetBtns.forEach((btn) => {
      if (btn.dataset.amount === "5") {
        btn.classList.add("active");
      } else {
        btn.classList.remove("active");
      }
    });
    if (customInput) customInput.value = "5";

    if (typeof dialog.showModal === "function") {
      dialog.showModal();
    } else {
      dialog.setAttribute("open", "");
    }
  }

  function closePayPalModal() {
    const dialog = document.getElementById("paypal-modal");
    if (dialog) {
      if (typeof dialog.close === "function") {
        dialog.close();
      } else {
        dialog.removeAttribute("open");
      }
    }
  }

  // --------------------------------------------------------------------------
  // Global Exports & Automatic Event Binding
  // --------------------------------------------------------------------------
  window.openRazorpayModal = function (e) {
    if (e && typeof e.preventDefault === "function") e.preventDefault();
    openRazorpayModal();
  };
  window.closeRazorpayModal = closeRazorpayModal;

  window.openPayPalModal = function (e) {
    if (e && typeof e.preventDefault === "function") e.preventDefault();
    openPayPalModal();
  };
  window.openApplePayModal = window.openPayPalModal;
  window.closePayPalModal = closePayPalModal;

  function bindPaymentButtons() {
    // Bind Razorpay Buttons
    document.querySelectorAll(".razorpay-btn").forEach((btn) => {
      if (!btn.dataset.rzpBound) {
        btn.dataset.rzpBound = "true";
        btn.addEventListener("click", (e) => {
          e.preventDefault();
          e.stopPropagation();
          openRazorpayModal();
        });
      }
    });

    // Bind PayPal Buttons
    document.querySelectorAll(".paypal-btn").forEach((btn) => {
      if (!btn.dataset.paypalBound) {
        btn.dataset.paypalBound = "true";
        btn.addEventListener("click", (e) => {
          e.preventDefault();
          e.stopPropagation();
          openPayPalModal();
        });
      }
    });

    // Bind Apple Pay Buttons
    document.querySelectorAll(".apple-pay-btn").forEach((btn) => {
      if (!btn.dataset.applePayBound) {
        btn.dataset.applePayBound = "true";
        btn.addEventListener("click", (e) => {
          e.preventDefault();
          e.stopPropagation();
          openPayPalModal();
        });
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bindPaymentButtons);
  } else {
    bindPaymentButtons();
  }
})();
