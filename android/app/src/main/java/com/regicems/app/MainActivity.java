package com.regicems.app;

import android.annotation.SuppressLint;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.textfield.TextInputEditText;

public class MainActivity extends AppCompatActivity {
    private static final String PREFS_NAME = "regice_ms_prefs";
    private static final String KEY_SERVER_URL = "server_url";
    private static final String DEFAULT_URL = "http://127.0.0.1:5000";

    private WebView webView;
    private SharedPreferences preferences;
    private LinearLayout errorContainer;
    private TextView errorMessageView;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        webView = findViewById(R.id.web_view);
        errorContainer = findViewById(R.id.error_container);
        errorMessageView = findViewById(R.id.error_message);
        MaterialToolbar toolbar = findViewById(R.id.top_app_bar);
        MaterialButton retryButton = findViewById(R.id.retry_button);
        MaterialButton changeServerButton = findViewById(R.id.change_server_button);

        toolbar.setOnMenuItemClickListener(item -> {
            if (item.getItemId() == R.id.action_change_server) {
                showServerDialog();
                return true;
            }
            if (item.getItemId() == R.id.action_reload) {
                loadConfiguredUrl();
                return true;
            }
            return false;
        });

        retryButton.setOnClickListener(view -> loadConfiguredUrl());
        changeServerButton.setOnClickListener(view -> showServerDialog());

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setAllowFileAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);

        webView.setWebChromeClient(new WebChromeClient());
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                showWebView();
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return false;
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                super.onReceivedError(view, request, error);
                if (request.isForMainFrame()) {
                    showErrorState(getString(R.string.error_message));
                }
            }
        });

        loadConfiguredUrl();
    }

    @Override
    public void onBackPressed() {
        if (webView.getVisibility() == View.VISIBLE && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    private void loadConfiguredUrl() {
        String url = preferences.getString(KEY_SERVER_URL, DEFAULT_URL);
        errorContainer.setVisibility(View.GONE);
        webView.setVisibility(View.VISIBLE);
        webView.loadUrl(url);
    }

    private void showErrorState(String message) {
        errorMessageView.setText(message);
        webView.setVisibility(View.GONE);
        errorContainer.setVisibility(View.VISIBLE);
    }

    private void showWebView() {
        errorContainer.setVisibility(View.GONE);
        webView.setVisibility(View.VISIBLE);
    }

    private void showServerDialog() {
        final TextInputEditText input = new TextInputEditText(this);
        input.setHint(DEFAULT_URL);
        input.setText(preferences.getString(KEY_SERVER_URL, DEFAULT_URL));
        input.setSingleLine(true);
        int padding = getResources().getDimensionPixelSize(R.dimen.dialog_padding);
        input.setPadding(padding, padding, padding, padding);

        AlertDialog dialog = new MaterialAlertDialogBuilder(this)
            .setTitle(R.string.server_dialog_title)
            .setMessage(R.string.server_dialog_message)
            .setView(input)
            .setNegativeButton(R.string.cancel, null)
            .setPositiveButton(R.string.save, (d, which) -> {
                String value = input.getText() == null ? "" : input.getText().toString().trim();
                if (value.isEmpty()) {
                    value = DEFAULT_URL;
                }
                preferences.edit().putString(KEY_SERVER_URL, value).apply();
                loadConfiguredUrl();
            })
            .create();

        dialog.show();
    }
}
