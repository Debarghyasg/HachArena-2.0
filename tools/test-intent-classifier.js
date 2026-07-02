/**
 * Intent-classifier regression suite (run: `npm run test:intent` or
 * `node --test tools/test-intent-classifier.js`).
 *
 * Guards the rule-based classifier in lib/knowledgeBase.js so common customer
 * phrasings are answered deterministically (free) instead of leaking to the
 * Medium-tier LLM fallback. Added after "wheres my order" was misrouted to the
 * LLM (and a generic handoff) because the order-status patterns required
 * "where is" / an order-noun-first and didn't tolerate the "wheres"/"where's"
 * contraction.
 */

const { test } = require('node:test');
const assert = require('node:assert/strict');
const kb = require('../lib/knowledgeBase');

const expect = (msg, want) => assert.equal(kb.detectIntent(msg).intent, want, `"${msg}" should be ${want}`);

test('order-status phrasings including the wheres/where-s contraction are caught for free', () => {
    for (const m of [
        'wheres my order', "where's my order", 'where is my order',
        'track my order', 'order status', 'status of my order',
        'my order', 'wheres my delivery', 'has my package shipped',
        'where is my refund', 'track my delivery',
    ]) expect(m, 'order_status');
});

test('order-status does NOT steal genuine location / policy / product / greeting intents', () => {
    expect('where is your store', 'store_location');
    expect('What is your return policy?', 'return_policy');
    expect('what are your opening hours', 'store_hours');
    expect('do you have milo in stock', 'product_query');
    expect('how much is the cordless drill', 'product_query');
    expect('hello there', 'greeting');
});

test('a described damage/refund claim still routes to the visual auditor', () => {
    expect('my drill is broken, i want a refund', 'return_claim');
    expect('refund please', 'return_claim');
});
